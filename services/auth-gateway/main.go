package main

import (
	"bytes"
	"context"
	"crypto/rand"
	"crypto/tls"
	"database/sql"
	"encoding/json"
	"fmt"
	"io"
	"log"
	"math/big"
	"mime/multipart"
	"net/http"
	"net/smtp"
	"net/url"
	"os"
	"strings"
	"sync"
	"time"

	_ "github.com/lib/pq"
)

// Config holds runtime configuration
type Config struct {
	Port         string
	PythonAIURL  string
	DBURL        string
	SupabaseURL  string
	SupabaseKey  string
	SMTPHost     string
	SMTPPort     string
	SMTPUser     string
	SMTPPass     string
	FromEmail    string
	ResendAPIKey string
}

func loadConfig() Config {
	loadDotEnv(".env")

	port := os.Getenv("PORT")
	if port == "" {
		port = "8090"
	}
	pyURL := os.Getenv("PYTHON_AI_URL")
	if pyURL == "" {
		pyURL = "http://localhost:8000"
	}
	dbURL := os.Getenv("SUPABASE_DB_URL")
	sbURL := getEnv("SUPABASE_URL", "https://wvmjshmpboquzyqwacxw.supabase.co")
	sbKey := getEnv("SUPABASE_API_KEY", "sb_publishable_uBli1Mro0fw58WBCEeYv3A_gWv7zwop")

	return Config{
		Port:         port,
		PythonAIURL:  pyURL,
		DBURL:        dbURL,
		SupabaseURL:  sbURL,
		SupabaseKey:  sbKey,
		SMTPHost:     getEnv("SMTP_HOST", "smtp.gmail.com"),
		SMTPPort:     getEnv("SMTP_PORT", "587"),
		SMTPUser:     os.Getenv("SMTP_USER"),
		SMTPPass:     os.Getenv("SMTP_PASS"),
		FromEmail:    getEnv("FROM_EMAIL", "Mpus Kampus <no-reply@mpus.daczdev.id>"),
		ResendAPIKey: os.Getenv("RESEND_API_KEY"),
	}
}

func loadDotEnv(filepath string) {
	data, err := os.ReadFile(filepath)
	if err != nil {
		return
	}
	lines := strings.Split(string(data), "\n")
	for _, line := range lines {
		line = strings.TrimSpace(line)
		if line == "" || strings.HasPrefix(line, "#") {
			continue
		}
		parts := strings.SplitN(line, "=", 2)
		if len(parts) == 2 {
			key := strings.TrimSpace(parts[0])
			val := strings.TrimSpace(parts[1])
			val = strings.Trim(val, `"'`)
			if os.Getenv(key) == "" {
				os.Setenv(key, val)
			}
		}
	}
}

func getEnv(key, fallback string) string {
	if v := os.Getenv(key); v != "" {
		return v
	}
	return fallback
}

// OTPRecord holds transient OTP state
type OTPRecord struct {
	Code       string    `json:"code"`
	ExpiresAt  time.Time `json:"expires_at"`
	Name       string    `json:"name"`
	NIM        string    `json:"nim"`
	CampusName string    `json:"campus_name"`
	Phone      string    `json:"phone"`
	UserID     string    `json:"user_id,omitempty"`
}

type OTPStore struct {
	mu   sync.RWMutex
	data map[string]OTPRecord
}

func newOTPStore() *OTPStore {
	return &OTPStore{
		data: make(map[string]OTPRecord),
	}
}

func (s *OTPStore) Set(email string, record OTPRecord) {
	s.mu.Lock()
	defer s.mu.Unlock()
	s.data[strings.ToLower(strings.TrimSpace(email))] = record
}

func (s *OTPStore) Get(email string) (OTPRecord, bool) {
	s.mu.RLock()
	defer s.mu.RUnlock()
	rec, ok := s.data[strings.ToLower(strings.TrimSpace(email))]
	return rec, ok
}

func (s *OTPStore) Delete(email string) {
	s.mu.Lock()
	defer s.mu.Unlock()
	delete(s.data, strings.ToLower(strings.TrimSpace(email)))
}

type Server struct {
	config Config
	store  *OTPStore
	client *http.Client
	db     *sql.DB
}

func initDB(primaryURL string) (*sql.DB, error) {
	if primaryURL == "" {
		return nil, fmt.Errorf("SUPABASE_DB_URL is empty")
	}

	ensureSSL := func(u string) string {
		if !strings.Contains(u, "sslmode=") {
			if strings.Contains(u, "?") {
				return u + "&sslmode=require"
			}
			return u + "?sslmode=require"
		}
		return u
	}

	url1 := ensureSSL(primaryURL)
	var url2 string
	if strings.Contains(url1, ":6543") {
		url2 = strings.Replace(url1, ":6543", ":5432", 1)
	} else if strings.Contains(url1, ":5432") {
		url2 = strings.Replace(url1, ":5432", ":6543", 1)
	}

	candidates := []string{url1}
	if url2 != "" && url2 != url1 {
		candidates = append(candidates, url2)
	}

	var lastErr error
	for _, rawURL := range candidates {
		masked := maskURL(rawURL)
		log.Printf("Connecting to PostgreSQL at %s...", masked)

		db, err := sql.Open("postgres", rawURL)
		if err != nil {
			lastErr = err
			continue
		}

		db.SetMaxOpenConns(25)
		db.SetMaxIdleConns(5)
		db.SetConnMaxLifetime(5 * time.Minute)
		db.SetConnMaxIdleTime(1 * time.Minute)

		ctx, cancel := context.WithTimeout(context.Background(), 4*time.Second)
		err = db.PingContext(ctx)
		cancel()

		if err == nil {
			log.Printf("✅ PostgreSQL connected and healthy at %s", masked)
			return db, nil
		}
		log.Printf("⚠️ Ping failed for %s: %v", masked, err)
		_ = db.Close()
		lastErr = err
	}

	return nil, lastErr
}

func maskURL(raw string) string {
	u, err := url.Parse(raw)
	if err != nil {
		return "[unparseable url]"
	}
	if u.User != nil {
		u.User = url.UserPassword(u.User.Username(), "******")
	}
	return u.String()
}

func main() {
	cfg := loadConfig()

	db, err := initDB(cfg.DBURL)
	if err != nil {
		log.Printf("⚠️ Direct PostgreSQL connection unavailable (%v). Using Supabase REST HTTPS engine as primary.", err)
	} else {
		defer db.Close()
	}

	srv := &Server{
		config: cfg,
		store:  newOTPStore(),
		client: &http.Client{Timeout: 35 * time.Second},
		db:     db,
	}

	mux := http.NewServeMux()

	// 1. Healthcheck
	mux.HandleFunc("GET /health", srv.handleHealth)

	// 2. Auth & Verification
	mux.HandleFunc("POST /api/v1/auth/register-ktm", srv.handleRegisterKTM)
	mux.HandleFunc("POST /api/v1/auth/verify-otp", srv.handleVerifyOTP)
	mux.HandleFunc("POST /api/v1/auth/resend-otp", srv.handleResendOTP)
	mux.HandleFunc("POST /api/v1/auth/sync-google", srv.handleSyncGoogle)

	// 3. User Profile
	mux.HandleFunc("GET /api/v1/profile/me", srv.handleGetProfile)
	mux.HandleFunc("PUT /api/v1/profile/me", srv.handleUpdateProfile)
	mux.HandleFunc("GET /api/v1/profile/search", srv.handleSearchProfile)

	// 4. Products Catalog
	mux.HandleFunc("GET /api/v1/products", srv.handleGetProducts)
	mux.HandleFunc("POST /api/v1/products", srv.handleCreateProduct)
	mux.HandleFunc("DELETE /api/v1/products", srv.handleDeleteProduct)

	// 5. Orders & Transactions
	mux.HandleFunc("GET /api/v1/orders", srv.handleGetOrders)
	mux.HandleFunc("POST /api/v1/orders", srv.handleCreateOrder)
	mux.HandleFunc("PATCH /api/v1/orders/status", srv.handleUpdateOrderStatus)

	handler := srv.corsMiddleware(mux)

	log.Printf("🐹 Mpus Golang Auth Gateway running on :%s (Python AI: %s | Supabase: %s)", cfg.Port, cfg.PythonAIURL, cfg.SupabaseURL)
	if err := http.ListenAndServe(":"+cfg.Port, handler); err != nil {
		log.Fatalf("Server failed to start: %v", err)
	}
}

func (s *Server) corsMiddleware(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Access-Control-Allow-Origin", "*")
		w.Header().Set("Access-Control-Allow-Methods", "GET, POST, PUT, DELETE, PATCH, OPTIONS")
		w.Header().Set("Access-Control-Allow-Headers", "Content-Type, Authorization, X-User-Id")
		if r.Method == http.MethodOptions {
			w.WriteHeader(http.StatusOK)
			return
		}
		next.ServeHTTP(w, r)
	})
}

// ----------------------------------------------------------------------------
// SUPABASE REST CLIENT HELPER
// ----------------------------------------------------------------------------

func (s *Server) supabaseRESTRequest(method, endpoint string, body any, preferReturn bool, authHeader string) ([]byte, int, error) {
	fullURL := fmt.Sprintf("%s/rest/v1/%s", strings.TrimSuffix(s.config.SupabaseURL, "/"), strings.TrimPrefix(endpoint, "/"))

	var bodyReader io.Reader
	if body != nil {
		jsonBytes, err := json.Marshal(body)
		if err != nil {
			return nil, 0, err
		}
		bodyReader = bytes.NewReader(jsonBytes)
	}

	req, err := http.NewRequest(method, fullURL, bodyReader)
	if err != nil {
		return nil, 0, err
	}

	req.Header.Set("apikey", s.config.SupabaseKey)
	if authHeader != "" && strings.HasPrefix(authHeader, "Bearer ") {
		req.Header.Set("Authorization", authHeader)
	} else {
		req.Header.Set("Authorization", "Bearer "+s.config.SupabaseKey)
	}
	req.Header.Set("Content-Type", "application/json")
	req.Header.Set("Accept", "application/json")
	if preferReturn {
		req.Header.Set("Prefer", "return=representation")
	}

	resp, err := s.client.Do(req)
	if err != nil {
		return nil, 0, err
	}
	defer resp.Body.Close()

	respBytes, err := io.ReadAll(resp.Body)
	if err != nil {
		return nil, resp.StatusCode, err
	}

	return respBytes, resp.StatusCode, nil
}

// ----------------------------------------------------------------------------
// HANDLERS
// ----------------------------------------------------------------------------

func (s *Server) handleHealth(w http.ResponseWriter, r *http.Request) {
	jsonResponse(w, http.StatusOK, map[string]any{
		"status":    "healthy",
		"service":   "mpus-golang-gateway",
		"version":   "1.0.0",
		"engine":    "Golang 1.22 + Supabase REST/PostgreSQL Engine",
		"architect": "DACZDev (Pak Bos Dimas)",
		"timestamp": time.Now().UTC().Format(time.RFC3339),
	})
}

type AIResponse struct {
	Success      bool   `json:"success"`
	Status       string `json:"status"`
	StudentName  string `json:"student_name"`
	StudentNIM   string `json:"student_nim"`
	CampusName   string `json:"campus_name"`
	ErrorMessage string `json:"error_message"`
	Message      string `json:"message"`
}

func (s *Server) handleRegisterKTM(w http.ResponseWriter, r *http.Request) {
	if err := r.ParseMultipartForm(32 << 20); err != nil {
		jsonError(w, http.StatusBadRequest, "Ukuran file terlalu besar atau form rusak")
		return
	}

	name := strings.TrimSpace(r.FormValue("name"))
	email := strings.ToLower(strings.TrimSpace(r.FormValue("email")))
	password := r.FormValue("password")
	nim := strings.TrimSpace(r.FormValue("nim"))
	phone := strings.TrimSpace(r.FormValue("phone"))
	userID := strings.TrimSpace(r.FormValue("user_id"))

	if name == "" || email == "" || password == "" || nim == "" {
		jsonError(w, http.StatusBadRequest, "Field name, email, password, dan nim wajib diisi")
		return
	}

	file, header, err := r.FormFile("file")
	if err != nil {
		jsonError(w, http.StatusBadRequest, "Foto KTM wajib diunggah (field: 'file')")
		return
	}
	defer file.Close()

	fileBytes, err := io.ReadAll(file)
	if err != nil {
		jsonError(w, http.StatusInternalServerError, "Gagal membaca berkas gambar KTM")
		return
	}

	// 1. Forward ke Python AI Microservice
	aiResult, err := s.callPythonAIVerifier(fileBytes, header.Filename, nim, name)
	if err != nil {
		log.Printf("AI Microservice error: %v", err)
		jsonError(w, http.StatusBadRequest, fmt.Sprintf("Validasi AI gagal: %v", err))
		return
	}

	if !aiResult.Success {
		errMsg := aiResult.ErrorMessage
		if errMsg == "" {
			errMsg = "Dokumen KTM tidak valid atau nomor NIM tidak terdeteksi oleh AI."
		}
		jsonError(w, http.StatusBadRequest, errMsg)
		return
	}

	// 2. Generate 6-Digit Cryptographic OTP
	otpPin, err := generateCryptoOTP()
	if err != nil {
		jsonError(w, http.StatusInternalServerError, "Gagal membuat kode OTP")
		return
	}

	campusName := aiResult.CampusName
	if campusName == "" {
		campusName = "Kampus Mahasiswa"
	}

	// 3. Simpan ke Cache
	s.store.Set(email, OTPRecord{
		Code:       otpPin,
		ExpiresAt:  time.Now().Add(10 * time.Minute),
		Name:       name,
		NIM:        nim,
		CampusName: campusName,
		Phone:      phone,
		UserID:     userID,
	})

	// 4. Kirim Email HTML Template Resmi Mpus
	go s.sendOTPEmail(email, name, otpPin, campusName)

	log.Printf("✅ Mahasiswa %s (%s) terverifikasi AI. OTP %s dikirim ke %s", name, nim, otpPin, email)

	jsonResponse(w, http.StatusOK, map[string]any{
		"success":     true,
		"message":     fmt.Sprintf("KTM Terverifikasi (%s). Kode OTP telah dikirimkan ke %s", campusName, email),
		"campus_name": campusName,
		"student_nim": aiResult.StudentNIM,
		"email":       email,
	})
}

func (s *Server) handleVerifyOTP(w http.ResponseWriter, r *http.Request) {
	var body struct {
		Email  string `json:"email"`
		OTP    string `json:"otp"`
		UserID string `json:"user_id"`
	}

	if err := json.NewDecoder(r.Body).Decode(&body); err != nil {
		jsonError(w, http.StatusBadRequest, "Payload JSON tidak valid")
		return
	}

	email := strings.ToLower(strings.TrimSpace(body.Email))
	otp := strings.TrimSpace(body.OTP)

	rec, exists := s.store.Get(email)
	if !exists {
		jsonError(w, http.StatusBadRequest, "Kode OTP tidak ditemukan atau sudah kadaluarsa")
		return
	}

	if time.Now().After(rec.ExpiresAt) {
		s.store.Delete(email)
		jsonError(w, http.StatusBadRequest, "Kode OTP telah kadaluarsa. Silakan minta kode baru.")
		return
	}

	if rec.Code != otp {
		jsonError(w, http.StatusBadRequest, "Kode OTP salah. Periksa kembali email Anda.")
		return
	}

	targetUserID := body.UserID
	if targetUserID == "" {
		targetUserID = rec.UserID
	}

	if targetUserID != "" {
		updatePayload := map[string]any{
			"id":                  targetUserID,
			"email":               email,
			"name":                rec.Name,
			"phone":               rec.Phone,
			"nim":                 rec.NIM,
			"campus_name":         rec.CampusName,
			"verification_status": "VERIFIED",
			"updated_at":          time.Now().UTC().Format(time.RFC3339),
		}
		_, _, _ = s.supabaseRESTRequest("POST", "profiles", updatePayload, true, r.Header.Get("Authorization"))
	}

	s.store.Delete(email)

	jsonResponse(w, http.StatusOK, map[string]any{
		"success":     true,
		"message":     "Verifikasi kode OTP berhasil! Akun Anda aktif.",
		"campus_name": rec.CampusName,
		"student_nim": rec.NIM,
		"email":       email,
	})
}

func (s *Server) handleResendOTP(w http.ResponseWriter, r *http.Request) {
	var body struct {
		Email string `json:"email"`
	}

	if err := json.NewDecoder(r.Body).Decode(&body); err != nil {
		jsonError(w, http.StatusBadRequest, "Payload JSON tidak valid")
		return
	}

	email := strings.ToLower(strings.TrimSpace(body.Email))
	rec, exists := s.store.Get(email)

	name := "Mahasiswa"
	campusName := "Kampus"
	nim := ""
	phone := ""
	userID := ""

	if exists {
		name = rec.Name
		campusName = rec.CampusName
		nim = rec.NIM
		phone = rec.Phone
		userID = rec.UserID
	}

	newOTP, err := generateCryptoOTP()
	if err != nil {
		jsonError(w, http.StatusInternalServerError, "Gagal membuat kode OTP baru")
		return
	}

	s.store.Set(email, OTPRecord{
		Code:       newOTP,
		ExpiresAt:  time.Now().Add(10 * time.Minute),
		Name:       name,
		NIM:        nim,
		CampusName: campusName,
		Phone:      phone,
		UserID:     userID,
	})

	go s.sendOTPEmail(email, name, newOTP, campusName)

	jsonResponse(w, http.StatusOK, map[string]any{
		"success":     true,
		"message":     fmt.Sprintf("Kode OTP baru telah dikirimkan ke %s", email),
		"campus_name": campusName,
		"email":       email,
	})
}

// ----------------------------------------------------------------------------
// PROFILE ENDPOINTS
// ----------------------------------------------------------------------------

func (s *Server) handleSyncGoogle(w http.ResponseWriter, r *http.Request) {
	var body struct {
		ID        string `json:"id"`
		Email     string `json:"email"`
		Name      string `json:"name"`
		AvatarURL string `json:"avatar_url"`
	}

	if err := json.NewDecoder(r.Body).Decode(&body); err != nil {
		jsonError(w, http.StatusBadRequest, "Invalid JSON payload")
		return
	}

	body.ID = strings.TrimSpace(body.ID)
	body.Email = strings.ToLower(strings.TrimSpace(body.Email))
	body.Name = strings.TrimSpace(body.Name)

	if body.ID == "" || body.Email == "" {
		jsonError(w, http.StatusBadRequest, "Field 'id' and 'email' are required")
		return
	}

	authHeader := r.Header.Get("Authorization")

	// 1. Cek apakah profil sudah ada
	existingBytes, _, _ := s.supabaseRESTRequest("GET", fmt.Sprintf("profiles?id=eq.%s&select=*", body.ID), nil, false, authHeader)
	var existingList []map[string]any
	_ = json.Unmarshal(existingBytes, &existingList)

	payload := map[string]any{
		"id":         body.ID,
		"email":      body.Email,
		"updated_at": time.Now().UTC().Format(time.RFC3339),
	}

	if body.Name != "" {
		payload["name"] = body.Name
	}
	if body.AvatarURL != "" {
		payload["avatar_url"] = body.AvatarURL
	}

	if len(existingList) == 0 {
		payload["created_at"] = time.Now().UTC().Format(time.RFC3339)
		payload["verification_status"] = "UNVERIFIED"
		resBytes, status, err := s.supabaseRESTRequest("POST", "profiles", payload, true, authHeader)
		if err != nil || status >= 400 {
			jsonError(w, http.StatusInternalServerError, "Gagal membuat profil pengguna baru")
			return
		}
		var created []map[string]any
		_ = json.Unmarshal(resBytes, &created)
		if len(created) > 0 {
			jsonResponse(w, http.StatusOK, map[string]any{"success": true, "data": created[0]})
			return
		}
	} else {
		resBytes, status, err := s.supabaseRESTRequest("PATCH", fmt.Sprintf("profiles?id=eq.%s", body.ID), payload, true, authHeader)
		if err != nil || status >= 400 {
			jsonError(w, http.StatusInternalServerError, "Gagal memperbarui profil pengguna")
			return
		}
		var updated []map[string]any
		_ = json.Unmarshal(resBytes, &updated)
		if len(updated) > 0 {
			jsonResponse(w, http.StatusOK, map[string]any{"success": true, "data": updated[0]})
			return
		}
	}

	jsonResponse(w, http.StatusOK, map[string]any{
		"success": true,
		"message": "Profil berhasil disinkronisasi",
	})
}

func (s *Server) handleGetProfile(w http.ResponseWriter, r *http.Request) {
	userID := s.extractUserID(r)
	if userID == "" {
		jsonError(w, http.StatusBadRequest, "Query param 'user_id' atau header 'X-User-Id' wajib disertakan")
		return
	}

	authHeader := r.Header.Get("Authorization")
	resBytes, status, err := s.supabaseRESTRequest("GET", fmt.Sprintf("profiles?id=eq.%s&select=*", userID), nil, false, authHeader)
	if err != nil || status >= 400 {
		jsonError(w, http.StatusInternalServerError, "Gagal mengambil data profil")
		return
	}

	var list []map[string]any
	if err := json.Unmarshal(resBytes, &list); err != nil || len(list) == 0 {
		jsonError(w, http.StatusNotFound, "Profil pengguna tidak ditemukan")
		return
	}

	jsonResponse(w, http.StatusOK, map[string]any{
		"success": true,
		"data":    list[0],
	})
}

func (s *Server) handleSearchProfile(w http.ResponseWriter, r *http.Request) {
	nim := strings.TrimSpace(r.URL.Query().Get("nim"))
	if nim == "" {
		jsonError(w, http.StatusBadRequest, "Parameter 'nim' wajib disertakan")
		return
	}

	authHeader := r.Header.Get("Authorization")
	resBytes, status, err := s.supabaseRESTRequest("GET", fmt.Sprintf("profiles?nim=eq.%s&select=*&limit=1", url.QueryEscape(nim)), nil, false, authHeader)
	if err != nil || status >= 400 {
		jsonError(w, http.StatusInternalServerError, "Gagal mencari data profil")
		return
	}

	var list []map[string]any
	_ = json.Unmarshal(resBytes, &list)
	if len(list) == 0 {
		jsonError(w, http.StatusNotFound, "Profil dengan NIM tersebut tidak ditemukan")
		return
	}

	jsonResponse(w, http.StatusOK, map[string]any{
		"success": true,
		"data":    list[0],
	})
}

func (s *Server) handleUpdateProfile(w http.ResponseWriter, r *http.Request) {
	userID := s.extractUserID(r)

	var body map[string]any
	if err := json.NewDecoder(r.Body).Decode(&body); err != nil {
		jsonError(w, http.StatusBadRequest, "Invalid JSON payload")
		return
	}

	if userID == "" {
		if uid, ok := body["user_id"].(string); ok {
			userID = strings.TrimSpace(uid)
		}
		if uid, ok := body["id"].(string); ok && userID == "" {
			userID = strings.TrimSpace(uid)
		}
	}

	if userID == "" {
		jsonError(w, http.StatusBadRequest, "user_id tidak ditemukan")
		return
	}

	delete(body, "user_id")
	body["updated_at"] = time.Now().UTC().Format(time.RFC3339)

	authHeader := r.Header.Get("Authorization")
	resBytes, status, err := s.supabaseRESTRequest("PATCH", fmt.Sprintf("profiles?id=eq.%s", userID), body, true, authHeader)
	if err != nil || status >= 400 {
		jsonError(w, http.StatusInternalServerError, fmt.Sprintf("Gagal memperbarui profil: status %d", status))
		return
	}

	var updated []map[string]any
	_ = json.Unmarshal(resBytes, &updated)
	if len(updated) > 0 {
		jsonResponse(w, http.StatusOK, map[string]any{
			"success": true,
			"message": "Profil berhasil diperbarui",
			"data":    updated[0],
		})
		return
	}

	jsonResponse(w, http.StatusOK, map[string]any{
		"success": true,
		"message": "Profil berhasil diperbarui",
	})
}

// ----------------------------------------------------------------------------
// PRODUCT ENDPOINTS
// ----------------------------------------------------------------------------

func (s *Server) handleGetProducts(w http.ResponseWriter, r *http.Request) {
	category := strings.TrimSpace(r.URL.Query().Get("category"))
	search := strings.TrimSpace(r.URL.Query().Get("search"))
	sellerID := strings.TrimSpace(r.URL.Query().Get("seller_id"))

	endpoint := "products?is_sold=eq.false&select=*,profiles:seller_id(*)"

	if category != "" && category != "Semua" {
		endpoint += fmt.Sprintf("&category=eq.%s", url.QueryEscape(category))
	}
	if search != "" {
		endpoint += fmt.Sprintf("&name=ilike.*%s*", url.QueryEscape(search))
	}
	if sellerID != "" {
		endpoint = fmt.Sprintf("products?seller_id=eq.%s&select=*,profiles:seller_id(*)&order=created_at.desc", sellerID)
	} else {
		endpoint += "&order=created_at.desc&limit=100"
	}

	authHeader := r.Header.Get("Authorization")
	resBytes, status, err := s.supabaseRESTRequest("GET", endpoint, nil, false, authHeader)
	if err != nil || status >= 400 {
		jsonError(w, http.StatusInternalServerError, "Gagal mengambil katalog produk")
		return
	}

	var list []map[string]any
	_ = json.Unmarshal(resBytes, &list)

	jsonResponse(w, http.StatusOK, map[string]any{
		"success": true,
		"count":   len(list),
		"data":    list,
	})
}

func (s *Server) handleCreateProduct(w http.ResponseWriter, r *http.Request) {
	var body map[string]any
	if err := json.NewDecoder(r.Body).Decode(&body); err != nil {
		jsonError(w, http.StatusBadRequest, "Invalid JSON payload")
		return
	}

	body["is_sold"] = false
	body["created_at"] = time.Now().UTC().Format(time.RFC3339)
	body["updated_at"] = time.Now().UTC().Format(time.RFC3339)

	authHeader := r.Header.Get("Authorization")
	resBytes, status, err := s.supabaseRESTRequest("POST", "products", body, true, authHeader)
	if err != nil || status >= 400 {
		jsonError(w, http.StatusInternalServerError, "Gagal menyimpan produk")
		return
	}

	var created []map[string]any
	_ = json.Unmarshal(resBytes, &created)
	if len(created) > 0 {
		jsonResponse(w, http.StatusCreated, map[string]any{
			"success": true,
			"message": "Produk berhasil diterbitkan",
			"data":    created[0],
		})
		return
	}

	jsonResponse(w, http.StatusCreated, map[string]any{
		"success": true,
		"message": "Produk berhasil diterbitkan",
	})
}

func (s *Server) handleDeleteProduct(w http.ResponseWriter, r *http.Request) {
	productID := strings.TrimSpace(r.URL.Query().Get("id"))
	if productID == "" {
		productID = strings.TrimPrefix(r.URL.Path, "/api/v1/products/")
	}

	if productID == "" {
		jsonError(w, http.StatusBadRequest, "ID produk wajib disertakan")
		return
	}

	authHeader := r.Header.Get("Authorization")
	_, status, err := s.supabaseRESTRequest("DELETE", fmt.Sprintf("products?id=eq.%s", productID), nil, false, authHeader)
	if err != nil || status >= 400 {
		jsonError(w, http.StatusInternalServerError, "Gagal menghapus produk")
		return
	}

	jsonResponse(w, http.StatusOK, map[string]any{
		"success": true,
		"message": "Produk berhasil dihapus",
	})
}

// ----------------------------------------------------------------------------
// ORDER ENDPOINTS
// ----------------------------------------------------------------------------

func (s *Server) handleGetOrders(w http.ResponseWriter, r *http.Request) {
	userID := s.extractUserID(r)
	role := strings.ToLower(strings.TrimSpace(r.URL.Query().Get("role")))

	endpoint := "orders?select=*,product:product_id(*),buyer:buyer_id(*),seller:seller_id(*)&order=created_at.desc"

	if role == "buyer" && userID != "" {
		endpoint += fmt.Sprintf("&buyer_id=eq.%s", userID)
	} else if role == "seller" && userID != "" {
		endpoint += fmt.Sprintf("&seller_id=eq.%s", userID)
	} else if userID != "" {
		endpoint += fmt.Sprintf("&or=(buyer_id.eq.%s,seller_id.eq.%s)", userID, userID)
	}

	authHeader := r.Header.Get("Authorization")
	resBytes, status, err := s.supabaseRESTRequest("GET", endpoint, nil, false, authHeader)
	if err != nil || status >= 400 {
		jsonError(w, http.StatusInternalServerError, "Gagal mengambil daftar pesanan")
		return
	}

	var list []map[string]any
	_ = json.Unmarshal(resBytes, &list)

	jsonResponse(w, http.StatusOK, map[string]any{
		"success": true,
		"count":   len(list),
		"data":    list,
	})
}

func (s *Server) handleCreateOrder(w http.ResponseWriter, r *http.Request) {
	var body map[string]any
	if err := json.NewDecoder(r.Body).Decode(&body); err != nil {
		jsonError(w, http.StatusBadRequest, "Invalid JSON payload")
		return
	}

	body["created_at"] = time.Now().UTC().Format(time.RFC3339)
	body["updated_at"] = time.Now().UTC().Format(time.RFC3339)

	authHeader := r.Header.Get("Authorization")
	resBytes, status, err := s.supabaseRESTRequest("POST", "orders", body, true, authHeader)
	if err != nil || status >= 400 {
		jsonError(w, http.StatusInternalServerError, "Gagal membuat pesanan")
		return
	}

	var created []map[string]any
	_ = json.Unmarshal(resBytes, &created)
	if len(created) > 0 {
		jsonResponse(w, http.StatusCreated, map[string]any{
			"success": true,
			"message": "Pesanan berhasil dibuat",
			"data":    created[0],
		})
		return
	}

	jsonResponse(w, http.StatusCreated, map[string]any{
		"success": true,
		"message": "Pesanan berhasil dibuat",
	})
}

func (s *Server) handleUpdateOrderStatus(w http.ResponseWriter, r *http.Request) {
	var body struct {
		OrderID string `json:"order_id"`
		Status  string `json:"status"`
	}

	if err := json.NewDecoder(r.Body).Decode(&body); err != nil {
		jsonError(w, http.StatusBadRequest, "Invalid JSON payload")
		return
	}

	body.OrderID = strings.TrimSpace(body.OrderID)
	if body.OrderID == "" || body.Status == "" {
		jsonError(w, http.StatusBadRequest, "Field 'order_id' dan 'status' wajib diisi")
		return
	}

	updatePayload := map[string]any{
		"status":     body.Status,
		"updated_at": time.Now().UTC().Format(time.RFC3339),
	}

	authHeader := r.Header.Get("Authorization")
	resBytes, status, err := s.supabaseRESTRequest("PATCH", fmt.Sprintf("orders?id=eq.%s", body.OrderID), updatePayload, true, authHeader)
	if err != nil || status >= 400 {
		jsonError(w, http.StatusInternalServerError, "Gagal memperbarui status order")
		return
	}

	var updated []map[string]any
	_ = json.Unmarshal(resBytes, &updated)
	if len(updated) > 0 {
		jsonResponse(w, http.StatusOK, map[string]any{
			"success": true,
			"message": "Status pesanan berhasil diperbarui",
			"data":    updated[0],
		})
		return
	}

	jsonResponse(w, http.StatusOK, map[string]any{
		"success": true,
		"message": "Status pesanan berhasil diperbarui",
	})
}

// ----------------------------------------------------------------------------
// HELPER FUNCTIONS
// ----------------------------------------------------------------------------

func (s *Server) extractUserID(r *http.Request) string {
	if uid := strings.TrimSpace(r.URL.Query().Get("user_id")); uid != "" {
		return uid
	}
	if uid := strings.TrimSpace(r.URL.Query().Get("id")); uid != "" {
		return uid
	}
	if uid := strings.TrimSpace(r.Header.Get("X-User-Id")); uid != "" {
		return uid
	}
	authHeader := r.Header.Get("Authorization")
	if strings.HasPrefix(authHeader, "Bearer ") {
		token := strings.TrimSpace(strings.TrimPrefix(authHeader, "Bearer "))
		if len(token) == 36 && strings.Count(token, "-") == 4 {
			return token
		}
	}
	return ""
}

func (s *Server) callPythonAIVerifier(imageBytes []byte, filename, expectedNim, expectedName string) (*AIResponse, error) {
	var body bytes.Buffer
	writer := multipart.NewWriter(&body)

	part, err := writer.CreateFormFile("file", filename)
	if err != nil {
		return nil, err
	}
	if _, err := part.Write(imageBytes); err != nil {
		return nil, err
	}

	if expectedNim != "" {
		_ = writer.WriteField("expected_nim", expectedNim)
	}
	if expectedName != "" {
		_ = writer.WriteField("expected_name", expectedName)
	}
	if err := writer.Close(); err != nil {
		return nil, err
	}

	aiURL := fmt.Sprintf("%s/api/v1/verify-upload", s.config.PythonAIURL)
	req, err := http.NewRequest("POST", aiURL, &body)
	if err != nil {
		return nil, err
	}
	req.Header.Set("Content-Type", writer.FormDataContentType())

	resp, err := s.client.Do(req)
	if err != nil {
		return nil, fmt.Errorf("koneksi ke AI Vision Microservice gagal: %w", err)
	}
	defer resp.Body.Close()

	respBytes, err := io.ReadAll(resp.Body)
	if err != nil {
		return nil, err
	}

	var aiResp AIResponse
	if err := json.Unmarshal(respBytes, &aiResp); err != nil {
		return nil, fmt.Errorf("gagal decode respon AI: %s", string(respBytes))
	}

	return &aiResp, nil
}

func generateCryptoOTP() (string, error) {
	n, err := rand.Int(rand.Reader, big.NewInt(900000))
	if err != nil {
		return "", err
	}
	return fmt.Sprintf("%06d", n.Int64()+100000), nil
}

func (s *Server) sendOTPEmail(toEmail, name, otpCode, campusName string) {
	subject := fmt.Sprintf("Kode Verifikasi Mpus: %s", otpCode)
	htmlBody := fmt.Sprintf(`<!DOCTYPE html>
<html lang="id">
<head><meta charset="UTF-8"><title>Kode Verifikasi Mpus</title></head>
<body style="margin: 0; padding: 0; font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Helvetica, Arial, sans-serif; background-color: #F3F8F8; color: #242D38;">
    <table border="0" cellpadding="0" cellspacing="0" width="100%%" style="padding: 30px 15px;">
        <tr>
            <td align="center">
                <table border="0" cellpadding="0" cellspacing="0" width="100%%" style="max-width: 520px; background-color: #FFFFFF; border-radius: 24px; overflow: hidden; box-shadow: 0 10px 30px rgba(0,0,0,0.06); border: 1px solid #E0F2F1;">
                    <tr>
                        <td align="center" style="background: linear-gradient(135deg, #00838F 0%%, #00ACC1 100%%); padding: 36px 24px;">
                            <div style="font-size: 32px; font-weight: 900; letter-spacing: 2px; color: #B4FFF9; text-transform: uppercase;">MPUS</div>
                            <div style="font-size: 14px; font-weight: 500; color: #FFFFFF; opacity: 0.9; margin-top: 4px;">Market Kampus Mahasiswa Indonesia (Go Backend)</div>
                        </td>
                    </tr>
                    <tr>
                        <td style="padding: 36px 28px;">
                            <div style="display: inline-block; background-color: #E0F7FA; color: #00838F; font-size: 12px; font-weight: 700; padding: 6px 14px; border-radius: 12px; margin-bottom: 16px;">
                                🛡️ KTM Terverifikasi AI (%s)
                            </div>
                            <h1 style="font-size: 20px; font-weight: 800; color: #242D38; margin: 0 0 12px 0;">Halo, %s! 👋</h1>
                            <p style="font-size: 14px; line-height: 1.6; color: #555555; margin: 0 0 24px 0;">
                                Foto KTM Anda telah berhasil divalidasi oleh AI Engine. Gunakan 6 digit kode OTP berikut untuk mengaktifkan akun Anda:
                            </p>
                            <div style="background-color: #F8FDFA; border: 2px dashed #00838F; border-radius: 16px; padding: 20px; text-align: center; margin-bottom: 24px;">
                                <div style="font-size: 12px; font-weight: 700; color: #666666; text-transform: uppercase; letter-spacing: 1px; margin-bottom: 8px;">KODE VERIFIKASI RESMI</div>
                                <div style="font-size: 38px; font-weight: 900; letter-spacing: 12px; color: #00838F; font-family: monospace;">%s</div>
                                <div style="font-size: 12px; color: #888888; margin-top: 8px;">⏱️ Berlaku selama 10 menit</div>
                            </div>
                            <p style="font-size: 13px; line-height: 1.5; color: #777777; margin: 0;">
                                Jangan bagikan kode ini kepada siapapun demi keamanan transaksi kampus Anda.
                            </p>
                        </td>
                    </tr>
                    <tr>
                        <td align="center" style="background-color: #FAFAFA; border-top: 1px solid #EEEEEE; padding: 20px 24px;">
                            <p style="font-size: 12px; color: #999999; margin: 0;">© 2026 DACZDev — Mpus Ecosystem by Pak Bos Dimas.</p>
                        </td>
                    </tr>
                </table>
            </td>
        </tr>
    </table>
</body>
</html>`, campusName, name, otpCode)

	if s.config.SMTPUser != "" && s.config.SMTPPass != "" {
		headers := make(map[string]string)
		headers["From"] = s.config.FromEmail
		headers["To"] = toEmail
		headers["Subject"] = subject
		headers["MIME-Version"] = "1.0"
		headers["Content-Type"] = "text/html; charset=UTF-8"

		var msg strings.Builder
		for k, v := range headers {
			msg.WriteString(fmt.Sprintf("%s: %s\r\n", k, v))
		}
		msg.WriteString("\r\n" + htmlBody)

		auth := smtp.PlainAuth("", s.config.SMTPUser, s.config.SMTPPass, s.config.SMTPHost)
		addr := fmt.Sprintf("%s:%s", s.config.SMTPHost, s.config.SMTPPort)

		var err error
		if s.config.SMTPPort == "465" {
			tlsconfig := &tls.Config{
				InsecureSkipVerify: false,
				ServerName:         s.config.SMTPHost,
			}
			conn, errDial := tls.Dial("tcp", addr, tlsconfig)
			if errDial == nil {
				client, errClient := smtp.NewClient(conn, s.config.SMTPHost)
				if errClient == nil {
					_ = client.Auth(auth)
					_ = client.Mail(s.config.SMTPUser)
					_ = client.Rcpt(toEmail)
					w, errW := client.Data()
					if errW == nil {
						_, _ = w.Write([]byte(msg.String()))
						_ = w.Close()
						_ = client.Quit()
					}
				}
			}
		} else {
			err = smtp.SendMail(addr, auth, s.config.SMTPUser, []string{toEmail}, []byte(msg.String()))
		}

		if err != nil {
			log.Printf("❌ SMTP Dispatch Error to %s: %v", toEmail, err)
		} else {
			log.Printf("📬 SMTP HTML Email successfully delivered to %s", toEmail)
		}
		return
	}

	log.Printf("📧 [DEV OTP EMAIL] Sent to %s: Code %s", toEmail, otpCode)
}

func jsonResponse(w http.ResponseWriter, status int, data any) {
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(status)
	_ = json.NewEncoder(w).Encode(data)
}

func jsonError(w http.ResponseWriter, status int, detail string) {
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(status)
	_ = json.NewEncoder(w).Encode(map[string]any{
		"success": false,
		"detail":  detail,
		"message": detail,
	})
}
