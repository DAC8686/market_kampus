package main

import (
	"bytes"
	"crypto/rand"
	"crypto/tls"
	"encoding/json"
	"fmt"
	"io"
	"log"
	"math/big"
	"mime/multipart"
	"net/http"
	"net/smtp"
	"os"
	"strings"
	"sync"
	"time"
)

// Config holds runtime configuration
type Config struct {
	Port         string
	PythonAIURL  string
	SMTPHost     string
	SMTPPort     string
	SMTPUser     string
	SMTPPass     string
	FromEmail    string
	ResendAPIKey string
}

func loadConfig() Config {
	port := os.Getenv("PORT")
	if port == "" {
		port = "8090"
	}
	pyURL := os.Getenv("PYTHON_AI_URL")
	if pyURL == "" {
		pyURL = "http://localhost:8000"
	}
	return Config{
		Port:         port,
		PythonAIURL:  pyURL,
		SMTPHost:     getEnv("SMTP_HOST", "smtp.gmail.com"),
		SMTPPort:     getEnv("SMTP_PORT", "587"),
		SMTPUser:     os.Getenv("SMTP_USER"),
		SMTPPass:     os.Getenv("SMTP_PASS"),
		FromEmail:    getEnv("FROM_EMAIL", "Mpus Kampus <no-reply@mpus.daczdev.id>"),
		ResendAPIKey: os.Getenv("RESEND_API_KEY"),
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
}

func main() {
	cfg := loadConfig()
	srv := &Server{
		config: cfg,
		store:  newOTPStore(),
		client: &http.Client{Timeout: 35 * time.Second},
	}

	mux := http.NewServeMux()
	mux.HandleFunc("GET /health", srv.handleHealth)
	mux.HandleFunc("POST /api/v1/auth/register-ktm", srv.handleRegisterKTM)
	mux.HandleFunc("POST /api/v1/auth/verify-otp", srv.handleVerifyOTP)
	mux.HandleFunc("POST /api/v1/auth/resend-otp", srv.handleResendOTP)

	// Wrap with CORS middleware
	handler := srv.corsMiddleware(mux)

	log.Printf("🐹 Mpus Golang Auth Gateway running on :%s (Connected to Python AI at %s)", cfg.Port, cfg.PythonAIURL)
	if err := http.ListenAndServe(":"+cfg.Port, handler); err != nil {
		log.Fatalf("Server failed to start: %v", err)
	}
}

func (s *Server) corsMiddleware(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Access-Control-Allow-Origin", "*")
		w.Header().Set("Access-Control-Allow-Methods", "GET, POST, PUT, DELETE, OPTIONS")
		w.Header().Set("Access-Control-Allow-Headers", "Content-Type, Authorization")
		if r.Method == http.MethodOptions {
			w.WriteHeader(http.StatusOK)
			return
		}
		next.ServeHTTP(w, r)
	})
}

func (s *Server) handleHealth(w http.ResponseWriter, r *http.Request) {
	jsonResponse(w, http.StatusOK, map[string]any{
		"status":    "healthy",
		"service":   "mpus-golang-gateway",
		"version":   "1.0.0",
		"engine":    "Golang 1.23 + Python Gemini Microservice",
		"architect": "DACZDev (Pak Bos Dimas)",
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

	if name == "" || email == "" || password == "" || nim == "" {
		jsonError(w, http.StatusBadRequest, "Semua field pendaftaran wajib diisi")
		return
	}

	file, header, err := r.FormFile("file")
	if err != nil {
		jsonError(w, http.StatusBadRequest, "Foto KTM wajib diunggah")
		return
	}
	defer file.Close()

	fileBytes, err := io.ReadAll(file)
	if err != nil {
		jsonError(w, http.StatusInternalServerError, "Gagal membaca berkas gambar KTM")
		return
	}

	// 1. Forward ke Python AI Microservice untuk validasi KTM
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
		Email string `json:"email"`
		OTP   string `json:"otp"`
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
		jsonError(w, http.StatusBadRequest, "Kode OTP telah kadaluarsa. Silakan klik 'Kirim Ulang'")
		return
	}

	if rec.Code != otp {
		jsonError(w, http.StatusBadRequest, "Kode OTP salah. Periksa kembali email Anda")
		return
	}

	// Success
	jsonResponse(w, http.StatusOK, map[string]any{
		"success":     true,
		"message":     "Verifikasi kode OTP berhasil",
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

	if exists {
		name = rec.Name
		campusName = rec.CampusName
		nim = rec.NIM
		phone = rec.Phone
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
	})

	go s.sendOTPEmail(email, name, newOTP, campusName)

	jsonResponse(w, http.StatusOK, map[string]any{
		"success":     true,
		"message":     fmt.Sprintf("Kode OTP baru telah dikirimkan ke %s", email),
		"campus_name": campusName,
		"email":       email,
	})
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
	htmlBody := fmt.Sprintf(`
<!DOCTYPE html>
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
</html>
`, campusName, name, otpCode)

	// SMTP Dispatch
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

	log.Printf("📧 [DEV OTP EMAIL] Sent to %s: Code %s (Configure SMTP_USER & SMTP_PASS in environment)", toEmail, otpCode)
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
