# File Processor 🚀

## Description

A high-performance file processing system built with **Elixir** and **Phoenix**. Designed to analyze, validate, and extract metrics from **CSV**, **JSON**, and **LOG** files.  

The system has evolved from a standard web app to a **Real-Time Reactive Dashboard** powered by **Phoenix LiveView**, offering a seamless experience where processing and visualization occur simultaneously via persistent connections.

---

## New Feature: LiveView Dashboards

The system now features a fully reactive architecture using **Phoenix.PubSub**:

* **Total Interactivity:** Eliminated "wait and redirect" flows. Results appear instantly as they are generated.
* **Unified Metrics Dashboard:** Errors and successes are integrated into a single view with contextual inspection, avoiding the confusion of multiple pages.
* **Dynamic Visualizations:**
    * **Live Donut Chart:** A real-time component showing the Success vs. Error ratio.
    * **Animated Count-Up Cards:** Metrics (Total, Processed, Warning, Errors) that update.
    * **Live Benchmark:** Visual "race" between Sequential and Parallel modes.
* **Contextual Error Inspector:** View line-by-line validation errors directly in the file list without page reloads using a dedicated "View Reason" interface.

---

## Key Features

* **Multi-format Support:** Specialized validators for CSV, JSON, and LOG files.
* **Hybrid Execution:** Choose between Sequential or Parallel processing using Elixir's lightweight processes.
* **Execution Control:** Configurable timeouts and worker management via `spawn_monitor` to detect and handle crashes gracefully.
* **Results Cache:** High-speed in-memory storage using Elixir `Agents` for real-time performance.
* **Filterable Progress Stream:** Real-time file list with quick filters (All, Completed, Warnings, Errors).

---

## Technical Architecture

* **Parallel and Sequential Processing:** Now non-blocking. They broadcasts events via **PubSub** whenever a file is processed.
* **LiveView Process:** Subscribes to processing events, updating the UI state without full-page refreshes.
* **Fault Tolerance:** Uses process monitors and blind-data handling in components to ensure the system remains stable even during heavy workloads or malformed data.

---

## Project Structure
    file_processor/
    ├── data/                       # Sample datasets
    │   ├── error/                  # Corrupt files for edge-case testing
    │   └── valid/                  # Standard CSV, JSON, and LOG files
    ├── lib/
    │   ├── file_processor/         # Core Logic & Concurrency
    │   │   ├── core/               # Dispatcher and Metrics definitions
    │   │   ├── execution/          # Strategies: Parallel, Sequential, Benchmark
    │   │   ├── formats/            # File parsers (CSV, JSON, LOG)
    │   │   ├── report/             # Text report generation
    │   │   └── results_cache.ex    # In-memory Agent storage
    │   └── file_processor_web/     # Phoenix LiveView Interface
    │       ├── components/         # Reactive UI (DonutChart, UploadForm, etc.)
    │       ├── live/               # LiveView Controllers (Real-time updates)
    │       └── endpoint.ex
    ├── priv/                       # Database migrations and static assets
    ├── test/                       # Comprehensive Test Suite
    │   ├── file_processor/         # Unit tests for core logic
    │   └── file_processor_web/     # Integration tests for LiveView
    └── mix.exs                     # Project configuration and dependencies

***

## Installation & Setup

### Requirements

*   **Elixir 1.14+**
*   **Erlang/OTP 25+**
*   **Node.js** (for Phoenix assets)

***

### 1. Install Dependencies

```bash
mix deps.get
```

### 2. Start the Web Server

```bash
mix phx.server
```

Visit: **<http://localhost:4000>**

***

## Usage

### Web Interface

1.  Navigate to the home page.
2.  Select your files (`.csv`, `.json`, `.log`).
3.  Choose the processing mode (Sequential, Parallel, Benchmark).
4.  View results and metrics directly on the dashboard.

***

## Testing

The project maintains a high standard of quality with an automatic test suite, covering edge cases, crash recovery, and data validation, which verify full processing flow from upload to report generation.

Run tests:

```bash
mix test
```

***

## Data Validation Specs

### **CSV**

*   Validates date format `YYYY-MM-DD`
*   Numeric types
*   Required headers

### **JSON**

*   User structures (IDs, names)
*   Session integrity (non-negative durations)

### **LOG**

*   Pattern:  
    `YYYY-MM-DD HH:MM:SS [LEVEL] [COMPONENT] Message`

***

Built with **Elixir & Phoenix LiveView**.

***
