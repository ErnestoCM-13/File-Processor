***

# File Processor 🚀

## Description

A high-performance file processing system built with **Elixir** and **Phoenix**. It is designed to analyze, validate, and extract metrics from **CSV**, **JSON**, and **LOG** files.  
The system supports multiple execution strategies (Sequential and Parallel) and includes a built-in **Benchmark** mode to compare performance metrics such as execution time and memory usage.

Now featuring a modern **Web Interface** built with **Phoenix LiveView** for a seamless user experience.

***

## Key Features

*   **Multi-format Support:** Specialized processors for CSV, JSON, and LOG files.
*   **Hybrid Execution:** Choose between sequential processing or highly concurrent parallel processing using Elixir's OTP lightweight processes.
*   **Robust Error Tracking:** Detailed logging of malformed lines, validation errors, and file system issues.
*   **Comprehensive Reporting:** Generates human-readable summaries and consolidated metrics.
*   **Web Dashboard:** Upload and process files directly from your browser.
*   **Advanced Benchmarking:** Real-time comparison between processing modes to visualize the *Elixir advantage*.

***

## Technical Objectives (Delivery 3)

*   **Fault Tolerance:** Uses `spawn_monitor` and process monitors to detect and gracefully handle worker crashes.
*   **Execution Control:** Implements configurable timeouts per process to prevent system hangs during heavy workloads.
*   **Resilience:** Automatic retry mechanism for transient processing failures.
*   **Enhanced Analytics:** Performance analysis including speedup factors and memory peak tracking.

***

## Project Structure

    file_processor/
    ├── lib/
    │   ├── file_processor/        # Core business logic
    │   │   ├── csv_processor.ex
    │   │   ├── json_processor.ex
    │   │   ├── log_processor.ex
    │   │   ├── report.ex           # Report generation engine
    │   │   └── executable.ex       # CLI logic
    │   ├── file_processor_web/     # Phoenix Web Interface
    │   │   ├── controllers/
    │   │   ├── components/
    │   │   └── endpoint.ex
    │   ├── parallel/               # Concurrency management
    │   │   ├── coordinator.ex      # Task orchestrator
    │   │   └── worker.ex           # Unit of work
    │   ├── file_processor.ex       # Main entry point
    │   └── benchmark.ex            # Performance measurement
    ├── test/                       # Full ExUnit test suite
    ├── data/                       # Sample datasets (valid and corrupt)
    └── output/                     # Generated text reports

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

### 3. Build the CLI Executable

```bash
mix escript.build
```

***

## Usage

### Web Interface

1.  Navigate to the home page.
2.  Select your files (`.csv`, `.json`, `.log`).
3.  Choose the processing mode (Sequential, Parallel, Benchmark).
4.  View results and metrics directly on the dashboard.

***

## Command Line Interface

The `file_processor` executable supports:

| Flag                   | Description                            |
| ---------------------- | -------------------------------------- |
| `-h`, `--help`         | Show usage guide                       |
| `-d --dir <path>`      | Process all files in a directory       |
| `-f --files <p1> <p2>` | Process a specific list of file paths  |
| `-p --parallel`        | Enable parallel processing             |
| `-b --benchmark`       | Run both modes and compare performance |
| `-t --timeout <ms>`    | Set timeout (default: 10000ms)         |

### CLI Examples

```bash
# Process a directory in parallel
./file_processor -d data/valid -p
```

```bash
# Run a benchmark comparison
./file_processor --files sales.csv logs.log -b
```

***

## Testing

The project maintains a high standard of quality with **50+ automated tests** covering edge cases, crash recovery, and data validation.

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

Developed with **Elixir & Phoenix**.

***


