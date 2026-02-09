# File Processor

## Description
This project implements a file processor in Elixir capable of analyzing CSV, JSON, and LOG files. It supports sequential and parallel execution, as well as a benchmark mode for comparison, extracting specific metrics and generating a summary report.

---

## Delivery 3 Objectives
- `Fault Tolerance`: Implementation of spawn_monitor to detect and handle worker crashes.
- `Execution Control`: Configurable timeouts per process to prevent system hangs.
- `Resilience`: Automatic retry mechanism for failed processing attempts.
- `Better Report`: Detailed log of corrupt files, internal parsing errors, and performance analysis.

---

## Project Structure
```lua
file_processor/ 
├── lib/ 
│ ├── file_processor/
│ │  ├── csv_processor.ex
│ │  ├── json_processor.ex
│ │  ├── log_processor.ex
│ │  ├── report_generator.ex
│ │  └── executable.ex
│ ├── parallel/
│ │  ├── coordinator.ex
│ │  └── worker.ex
│ ├── file_processor.ex 
│ └── benchmark.ex
├── data/ 
│ ├── valid/ 
│ │ ├── ventas_enero.csv 
│ │ ├── ventas_febrero.csv 
│ │ ├── usuarios.json 
│ │ ├── sesiones.json 
│ │ ├── sistema.log 
│ │ └── aplicacion.log 
│ └── error/ 
│   ├── ventas_corrupto.csv 
│   └── usuarios_malformado.json 
├── output/ 
│ └── [generated reports] 
├── test 
│ ├── file_processor_test.exs 
│ ├── csv_processor_test.ex 
│ ├── json_processor_test.ex 
│ ├── log_processor_test.ex 
│ ├── benchmark_test.ex
│ └── test_helper.exs 
├── .formatter.exs 
├── .gitignore 
├── mix.exs 
└── README.md
```

---

## Supported File Types
**CSV (`.csv`)**
- **Expected structure:**
```csv
fecha,producto,categoria,precio_unitario,cantidad,descuento
YYYY-MM-DD,string,string,float,integer,float
```
- **Generated metrics:**
  - Total sales
  - Unique products count
  - Top product
  - Top category
  - Average discount
  - Date range
  - Processed lines

**JSON (`.json`)**
- **Expected structure:**
```json
{
  "timestamp": "ISO-8601",
  "usuarios": [
    {
      "id": integer,
      "nombre": string,
      "email": string,
      "activo": boolean,
      "ultimo_acceso": "ISO-8601"
    }
  ],
  "sesiones": [
    {
      "usuario_id": integer,
      "inicio": "ISO-8601",
      "duracion_segundos": integer,
      "paginas_visitadas": integer,
      "acciones": [string]
    }
  ]
}
```
- **Generated metrics:**
  - Total users
  - Active percent
  - Average session duration
  - Total pages visited
  - Top 5 actions
  - Peak hour
  - Total sessions

**LOG (`.log`)**
- **Expected structure:**
```
YYYY-MM-DD HH:MM:SS [NIVEL] [COMPONENTE] Mensaje de log
```
- **Generated metrics:**
  - Total entries
  - Level distribution
  - Most problematic component
  - Frequent error pattern
  - Peak log hour

---

## Installation Guide

### Requirements
- Elixir 1.14 or higher
- Erlang/OTP 25 or higher

### Setup
1. Install dependencies:
```bash
mix deps.get
```
2. Generate the executable:
```bash
mix escript.build
```
---

## Usage
The project generates a "file_processor" executable, which can be used to process an entire directory or a specific file or list of files. 
You can add flags to toggle the processing mode between sequential (deffault mode), parallel, and benchmark; the latter executes both modes and measures their execution times to generate a performance comparison.
You can also use --help or -h to print the executable's usage guide to the console.

### Command Line Options:
The executable file_processor supports the following flags:

- `-h, --help`: Prints the usage guide.
- `-d, --dir <path>`: Process all files in a directory.
- `-f, --files <p1> <p2>`: Process a specific list of files.
- `-p, --parallel`: Enable parallel processing.
- `-b, --benchmark`: Run both modes and compare performance.
- `-t, --timeout <ms>`: Set processing timeout (default: 10000ms).

### Examples:
- Process `data/valid/ventas.csv` file in sequentiall mode
  ```bash
  ./file_processor -f data/valid/ventas.csv
  ```
- Process `data/valid/usuarios.json` and `data/error/sistema_corrupto.log` files in parallel mode
  ```bash
  ./file_processor --files data/valid/usuarios.json data/error/sistema_corrupto.log -p
    ```
- Process `data/valid` directory in benchmark mode
  ```bash
  ./file_processor -d data/valid -b
  ```

---

## Testing
The project uses ExUnit for automated testing. It includes tests for the main module, individual processors, and the benchmark module.
**Run tests**:
```bash
mix test
```

---

## Changes
### Added
* **Error Tracking:** Introduced detailed error logging for `CsvProcessor`, `JasonProcessor`, and `LogProcessor`. The system now captures specific line numbers and failure reasons.
* **Validation Logic:** * New `validate_date/1` using Regex pattern matching.
    * New `validate_user/1` (checks ID type and username existence) and `validate_session/1` (ensures positive duration) in `JasonProcessor`.
* **Parallel Processing Enhancements:**
    * Added support for `timeout` and `max_retries` configurations via a new `config` map.
    * Implemented `check_completion/4` to dynamically monitor worker status and handle process termination.
* **Reporting & Analytics:**
    * Added `Executive Summary` section to the final report.
    * Added `Performance Analysis` section to compare sequential vs. parallel execution times.
    * New `calculate_improvement/2` utility to determine performance speedup factors.
    * New `add_consolidated/2` function to calculate totals across all CSV files.
* **CLI Options:** Added `--timeout` and `--retries` flags to the executable `main/1` function.

### Changed
* **Parallel Coordinator Refactor:**
    * Updated `init` and `start` to handle the new configuration map.
    * Optimized worker management: The `state` now uses a `%{PID => file}` map for better tracking and monitoring.
    * Refactored the main `loop/2` to handle global timeouts and individual worker failures gracefully.
* **Processor Improvements:**
    * **CSV:** `process_lines/3` now tracks the current line index for precise error reporting.
    * **CSV:** Renamed internal validation functions (e.g., `validate_float/2`, `validate_int/2`) for better clarity and added descriptive error messages.
    * **Logging:** Improved error message clarity across all parsing modules.
* **Metrics & Benchmarking:**
    * `measure/1` now collects system memory usage (`:erlang.memory`) and process counts (`:erlang.system_info`).
    * `update_metrics_map/2` updated to merge detailed parsing errors into the final results.
* **Report Generation:**
    * `format_entry/2` converted to a multi-clause function for specialized formatting per data type.
    * `add_errors/2` now differentiates between fatal system errors and individual line parsing errors.

### Removed
* **Redundant Parsers:** `parse_user/1` and `parse_session/1` in favor of the new validation logic.
* **Cleaned up Logic:** `print_benchmark/2` and `get_keys_order/1` were removed as their functionality was integrated into the new reporting engine.
* **State Cleanup:** Removed the `:results` key from the Coordinator state to favor a more direct worker-to-metrics flow.

###ssh
