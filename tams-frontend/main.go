package main

import (
	"bytes"
	"encoding/json"
	"fmt"
	"html/template"
	"io"
	"log"
	"mime/multipart"
	"net/http"
	"os"
	"time"

	"github.com/gorilla/mux"
)

type Config struct {
	TamsAPIURL string
	Port       string
}

type Source struct {
	ID          string                 `json:"id"`
	Label       string                 `json:"label"`
	Description string                 `json:"description,omitempty"`
	Tags        map[string]interface{} `json:"tags,omitempty"`
	CreatedAt   time.Time              `json:"created_at"`
	UpdatedAt   time.Time              `json:"updated_at"`
}

type Flow struct {
	ID             string                 `json:"id"`
	SourceID       string                 `json:"source_id"`
	Label          string                 `json:"label"`
	Description    string                 `json:"description,omitempty"`
	Format         string                 `json:"format"`
	Codec          string                 `json:"codec,omitempty"`
	Tags           map[string]interface{} `json:"tags,omitempty"`
	TimerangeStart string                 `json:"timerange_start,omitempty"`
	TimerangeEnd   string                 `json:"timerange_end,omitempty"`
	CreatedAt      time.Time              `json:"created_at"`
	UpdatedAt      time.Time              `json:"updated_at"`
}

type Segment struct {
	ID             string                 `json:"id"`
	FlowID         string                 `json:"flow_id"`
	TimerangeStart string                 `json:"timerange_start"`
	TimerangeEnd   string                 `json:"timerange_end"`
	Duration       float64                `json:"duration,omitempty"`
	StorageURI     string                 `json:"storage_uri"`
	SizeBytes      int64                  `json:"size_bytes,omitempty"`
	Tags           map[string]interface{} `json:"tags,omitempty"`
	CreatedAt      time.Time              `json:"created_at"`
}

var (
	config    Config
	templates *template.Template
)

func init() {
	config = Config{
		TamsAPIURL: getEnv("TAMS_API_URL", "http://localhost:8080"),
		Port:       getEnv("PORT", "8090"),
	}
}

func getEnv(key, defaultValue string) string {
	if value := os.Getenv(key); value != "" {
		return value
	}
	return defaultValue
}

func main() {
	// Parse templates
	var err error
	templates, err = template.ParseGlob("templates/*.html")
	if err != nil {
		log.Fatalf("Error parsing templates: %v", err)
	}

	// Setup router
	r := mux.NewRouter()

	// Routes
	r.HandleFunc("/", indexHandler).Methods("GET")
	r.HandleFunc("/health", healthHandler).Methods("GET")
	r.HandleFunc("/sources", listSourcesHandler).Methods("GET")
	r.HandleFunc("/sources/create", createSourceHandler).Methods("POST")
	r.HandleFunc("/flows", listFlowsHandler).Methods("GET")
	r.HandleFunc("/flows/create", createFlowHandler).Methods("POST")
	r.HandleFunc("/segments", listSegmentsHandler).Methods("GET")
	r.HandleFunc("/segments/create", createSegmentHandler).Methods("POST")
	r.HandleFunc("/segments/upload", uploadSegmentPageHandler).Methods("GET")

	// Static files
	r.PathPrefix("/static/").Handler(http.StripPrefix("/static/", http.FileServer(http.Dir("static"))))

	// Start server
	addr := "0.0.0.0:" + config.Port
	log.Printf("Starting TAMS Frontend on %s", addr)
	log.Printf("TAMS API URL: %s", config.TamsAPIURL)
	log.Fatal(http.ListenAndServe(addr, r))
}

func healthHandler(w http.ResponseWriter, r *http.Request) {
	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(map[string]string{
		"status": "healthy",
		"time":   time.Now().Format(time.RFC3339),
	})
}

func indexHandler(w http.ResponseWriter, r *http.Request) {
	data := map[string]interface{}{
		"Title": "TAMS Test Drive",
	}
	templates.ExecuteTemplate(w, "index.html", data)
}

func listSourcesHandler(w http.ResponseWriter, r *http.Request) {
	resp, err := http.Get(config.TamsAPIURL + "/sources")
	if err != nil {
		http.Error(w, "Error fetching sources", http.StatusInternalServerError)
		log.Printf("Error fetching sources: %v", err)
		return
	}
	defer resp.Body.Close()

	var sources []Source
	if err := json.NewDecoder(resp.Body).Decode(&sources); err != nil {
		http.Error(w, "Error decoding sources", http.StatusInternalServerError)
		log.Printf("Error decoding sources: %v", err)
		return
	}

	data := map[string]interface{}{
		"Title":   "Sources",
		"Sources": sources,
	}
	templates.ExecuteTemplate(w, "sources.html", data)
}

func createSourceHandler(w http.ResponseWriter, r *http.Request) {
	if err := r.ParseForm(); err != nil {
		http.Error(w, "Error parsing form", http.StatusBadRequest)
		return
	}

	source := map[string]interface{}{
		"id":          r.FormValue("id"),
		"label":       r.FormValue("label"),
		"description": r.FormValue("description"),
		"tags":        map[string]interface{}{},
	}

	jsonData, _ := json.Marshal(source)
	resp, err := http.Post(config.TamsAPIURL+"/sources", "application/json", bytes.NewBuffer(jsonData))
	if err != nil {
		http.Error(w, "Error creating source", http.StatusInternalServerError)
		log.Printf("Error creating source: %v", err)
		return
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusCreated {
		body, _ := io.ReadAll(resp.Body)
		http.Error(w, fmt.Sprintf("Error creating source: %s", body), resp.StatusCode)
		return
	}

	http.Redirect(w, r, "/sources", http.StatusSeeOther)
}

func listFlowsHandler(w http.ResponseWriter, r *http.Request) {
	sourceID := r.URL.Query().Get("source_id")
	url := config.TamsAPIURL + "/flows"
	if sourceID != "" {
		url += "?source_id=" + sourceID
	}

	resp, err := http.Get(url)
	if err != nil {
		http.Error(w, "Error fetching flows", http.StatusInternalServerError)
		log.Printf("Error fetching flows: %v", err)
		return
	}
	defer resp.Body.Close()

	var flows []Flow
	if err := json.NewDecoder(resp.Body).Decode(&flows); err != nil {
		http.Error(w, "Error decoding flows", http.StatusInternalServerError)
		log.Printf("Error decoding flows: %v", err)
		return
	}

	// Get sources for dropdown
	sourcesResp, err := http.Get(config.TamsAPIURL + "/sources")
	var sources []Source
	if err == nil {
		json.NewDecoder(sourcesResp.Body).Decode(&sources)
		sourcesResp.Body.Close()
	}

	data := map[string]interface{}{
		"Title":   "Flows",
		"Flows":   flows,
		"Sources": sources,
	}
	templates.ExecuteTemplate(w, "flows.html", data)
}

func createFlowHandler(w http.ResponseWriter, r *http.Request) {
	if err := r.ParseForm(); err != nil {
		http.Error(w, "Error parsing form", http.StatusBadRequest)
		return
	}

	flow := map[string]interface{}{
		"id":          r.FormValue("id"),
		"source_id":   r.FormValue("source_id"),
		"label":       r.FormValue("label"),
		"description": r.FormValue("description"),
		"format":      r.FormValue("format"),
		"codec":       r.FormValue("codec"),
		"tags":        map[string]interface{}{},
	}

	jsonData, _ := json.Marshal(flow)
	resp, err := http.Post(config.TamsAPIURL+"/flows", "application/json", bytes.NewBuffer(jsonData))
	if err != nil {
		http.Error(w, "Error creating flow", http.StatusInternalServerError)
		log.Printf("Error creating flow: %v", err)
		return
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusCreated {
		body, _ := io.ReadAll(resp.Body)
		http.Error(w, fmt.Sprintf("Error creating flow: %s", body), resp.StatusCode)
		return
	}

	http.Redirect(w, r, "/flows", http.StatusSeeOther)
}

func listSegmentsHandler(w http.ResponseWriter, r *http.Request) {
	flowID := r.URL.Query().Get("flow_id")
	url := config.TamsAPIURL + "/segments"
	if flowID != "" {
		url += "?flow_id=" + flowID
	}

	resp, err := http.Get(url)
	if err != nil {
		http.Error(w, "Error fetching segments", http.StatusInternalServerError)
		log.Printf("Error fetching segments: %v", err)
		return
	}
	defer resp.Body.Close()

	var segments []Segment
	if err := json.NewDecoder(resp.Body).Decode(&segments); err != nil {
		http.Error(w, "Error decoding segments", http.StatusInternalServerError)
		log.Printf("Error decoding segments: %v", err)
		return
	}

	// Get flows for dropdown
	flowsResp, err := http.Get(config.TamsAPIURL + "/flows")
	var flows []Flow
	if err == nil {
		json.NewDecoder(flowsResp.Body).Decode(&flows)
		flowsResp.Body.Close()
	}

	data := map[string]interface{}{
		"Title":    "Segments",
		"Segments": segments,
		"Flows":    flows,
	}
	templates.ExecuteTemplate(w, "segments.html", data)
}

func uploadSegmentPageHandler(w http.ResponseWriter, r *http.Request) {
	// Get flows for dropdown
	flowsResp, err := http.Get(config.TamsAPIURL + "/flows")
	var flows []Flow
	if err == nil {
		json.NewDecoder(flowsResp.Body).Decode(&flows)
		flowsResp.Body.Close()
	}

	data := map[string]interface{}{
		"Title": "Upload Segment",
		"Flows": flows,
	}
	templates.ExecuteTemplate(w, "upload.html", data)
}

func createSegmentHandler(w http.ResponseWriter, r *http.Request) {
	if err := r.ParseMultipartForm(100 << 20); err != nil { // 100 MB max
		http.Error(w, "Error parsing form", http.StatusBadRequest)
		return
	}

	file, handler, err := r.FormFile("file")
	if err != nil {
		http.Error(w, "Error retrieving file", http.StatusBadRequest)
		return
	}
	defer file.Close()

	// Create multipart form
	body := &bytes.Buffer{}
	writer := multipart.NewWriter(body)

	// Add form fields
	fields := map[string]string{
		"id":              r.FormValue("id"),
		"flow_id":         r.FormValue("flow_id"),
		"timerange_start": r.FormValue("timerange_start"),
		"timerange_end":   r.FormValue("timerange_end"),
	}

	// Write segment JSON
	segmentData, _ := json.Marshal(fields)
	writer.WriteField("segment", string(segmentData))

	// Add file
	part, err := writer.CreateFormFile("file", handler.Filename)
	if err != nil {
		http.Error(w, "Error creating form file", http.StatusInternalServerError)
		return
	}
	io.Copy(part, file)
	writer.Close()

	// Send to API
	req, err := http.NewRequest("POST", config.TamsAPIURL+"/segments", body)
	if err != nil {
		http.Error(w, "Error creating request", http.StatusInternalServerError)
		return
	}
	req.Header.Set("Content-Type", writer.FormDataContentType())

	client := &http.Client{}
	resp, err := client.Do(req)
	if err != nil {
		http.Error(w, "Error uploading segment", http.StatusInternalServerError)
		log.Printf("Error uploading segment: %v", err)
		return
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusCreated {
		respBody, _ := io.ReadAll(resp.Body)
		http.Error(w, fmt.Sprintf("Error creating segment: %s", respBody), resp.StatusCode)
		return
	}

	http.Redirect(w, r, "/segments", http.StatusSeeOther)
}
