defmodule FileProcessor.CsvProcessor do
  @moduledoc """
  Specialized processor for CSV files.
  This module is delegated by `FileProcessor` when a `.csv` file is detected.
  It reads the file line by line using `NimbleCSV`, validates and parses each row,
  accumulates data, and calculates metrics.

  ## Expected CSV colums:
  1. Date (YYYY-MM-DD)
  2. Product name
  3. Category
  4. Unit price
  5. Quantity sold
  6. Discount percentage

  ## Calculated metrics:
  - Total sales (after discounts)
  - Number of unique products
  - Average discount applied
  - Top-selling product
  - Top-selling category
  - Date range
  - Total processed lines
  - Error count and details
  """

  # CSV parser configuration:
  # - "," as column separator
  # - "°" as escape character
  NimbleCSV.define(CsvParser, separator: ",", escape: "°")

  # ----------------------------------------------------------------------
  # PUBLIC API
  # ----------------------------------------------------------------------

  @doc """
  Entry point for the module.
  Processes a CSV file and returns a map containing calculated metrics.

  ## Processing flow
  1. Stream file contents
  2. Parse CSV file rows
  3. Validate and accumulate row data
  4. Calcule final metrics
  """
  def process_csv_file(csv_file_path) do
    parsed_lines =
      csv_file_path
      |> File.stream!()
      |> CsvParser.parse_stream()
      |> Enum.to_list()

    metrics =
      set_initial_metrics_accumulator()
      |> process_lines(parsed_lines, 1)
      |> build_final_metrics()

    {:ok, metrics}
  end

  # ----------------------------------------------------------------------
  # METRICS ACUMULATOR INITIALIZATION
  # ----------------------------------------------------------------------

  @doc false
  # Initializes the data accumulator with default values for CSV metrics.
  defp set_initial_metrics_accumulator() do
    %{
      total_sales: 0.0,
      unique_products: MapSet.new(),
      discounts: [],
      product_stats: %{},  # %{"product_name" => total_quantity}
      category_stats: %{}, # %{"category" => total_sales}
      earliest_date: nil,
      latest_date: nil,
      processed_lines_count: 0,
      error_lines: []
    }
  end

  # ----------------------------------------------------------------------
  # LINE PROCESSING
  # ----------------------------------------------------------------------

  @doc false
  # Iterates over the list of lines,
  # parsing them using the parse_and_validate_line/1 function.
  defp process_lines(accumulator, [], _line_number), do: accumulator
  defp process_lines(accumulator, [first_line | remaining_lines], line_number) do
    updated_accumulator =
      case parse_and_validate_line(first_line) do
        {:ok, parsed_line} ->
          update_accumulator(accumulator, parsed_line)

        {:error, reason} ->
          Map.update!(accumulator, :error_lines, fn errors ->
            ["line #{line_number}: #{reason}" | errors]
          end)
      end

    process_lines(updated_accumulator, remaining_lines, line_number + 1)
  end

  # ----------------------------------------------------------------------
  # LINE PARSING AND VALIDATION
  # ----------------------------------------------------------------------

  @doc false
  # Transforms a list of strings into a structured map with data types.
  # Performs type and range validations for price, quantity, and discount
  defp parse_and_validate_line([date, product_name, category, unit_price, quantity, discount]) do
    with {:ok, parsed_date} <- validate_date_format(date),
         {:ok, parsed_price} <- validate_positive_float(unit_price, "Invalid price"),
         {:ok, parsed_quantity} <- validate_positive_integer(quantity, "Invalid quantity"),
         {:ok, parsed_discount} <- validate_discount_percentage(discount) do
      {:ok,
        %{
          date: parsed_date,
          product: product_name,
          category: category,
          price: parsed_price,
          quantity: parsed_quantity,
          discount: parsed_discount
      }}
    else
      {:error, reason} -> {:error, reason}
    end
  end

  # Error clause for lines with corrupt lines.
  defp parse_and_validate_line(_), do: {:error, "Corrupt line (missing columns)"}

  # ----------------------------------------------------------------------
  # ACCUMULATION LOGIC
  # ----------------------------------------------------------------------

  @doc false
  # Updates the accumulator data with information from a successfully parsed line.
  # Calculates the sales amount (applying discounts) before adding it to the totals.
  defp update_accumulator(accumulator, parsed_line) do
    sale_total = calculate_discounted_sale_total(parsed_line)

    %{
      accumulator |
      total_sales: accumulator.total_sales + sale_total,
      unique_products: MapSet.put(accumulator.unique_products, parsed_line.product),
      discounts: [parsed_line.discount | accumulator.discounts],
      product_stats:
        Map.update(
          accumulator.product_stats,
          parsed_line.product,
          parsed_line.quantity,
          &(&1 + parsed_line.quantity)
        ),
      category_stats:
        Map.update(
          accumulator.category_stats,
          parsed_line.category,
          sale_total,
          &(&1 + sale_total)
          ),
      earliest_date: pick_realiest_date(accumulator.earliest_date, parsed_line.date),
      latest_date: pick_latest_date(accumulator.latest_date, parsed_line.date),
      processed_lines_count: accumulator.processed_lines_count + 1
    }
  end

  # ----------------------------------------------------------------------
  # VALIDATION HELPERS
  # ----------------------------------------------------------------------

  @doc false
  # Validates prices are positive.
  defp validate_positive_float(value, error_message) do
    case Float.parse(value) do
      {number, _} when number >= 0 -> {:ok, number}
      _ -> {:error, error_message}
    end
  end

  @doc false
  # Validates quantity is positive.
  defp validate_positive_integer(value, error_message) do
    case Integer.parse(value) do
      {number, _} when number > 0 -> {:ok, number}
      _ -> {:error, error_message}
    end
  end

  @doc false
  # Validates discount is between 0 and 100%.
  defp validate_discount_percentage(value) do
    case Float.parse(value) do
      {number, _} when number >= 0 and number <= 100 -> {:ok, number}
      _ -> {:error, "Discount out of range (0-100)"}
    end
  end

  @doc false
  # Validates date format is correct.
  defp validate_date_format(date_string) do
    if String.match?(date_string, ~r/^\d{4}-\d{2}-\d{2}$/) do
      {:ok, date_string}
    else
      {:error, "Invalid date format"}
    end
  end

  # ----------------------------------------------------------------------
  # DATE HELPERS
  # ----------------------------------------------------------------------

  @doc false
  # Date comparison helpers for string formats.
  defp pick_realiest_date(nil, new_date), do: new_date
  defp pick_realiest_date(current_date, new_date), do: if(new_date < current_date, do: new_date, else: current_date)

  defp pick_latest_date(nil, new_date), do: new_date
  defp pick_latest_date(current_date, new_date), do: if(new_date > current_date, do: new_date, else: current_date)

  # ----------------------------------------------------------------------
  # METRICS FINALIZATION
  # ----------------------------------------------------------------------

  @doc false
  # Uses the accumulator data to calculate metrics and stores them in a map with
  # data that the Report module can convert into a string.
  defp build_final_metrics(accumulator) do
    # Search the top quantity product
    {top_product, top_quantity} =
      if map_size(accumulator.product_stats) > 0 do
        Enum.max_by(accumulator.product_stats, fn {_product, quantity} -> quantity end)
      else
        {"N/A", 0}
      end

    # Search the top revenue category
    {top_category, top_revenue} =
      if map_size(accumulator.category_stats) > 0 do
        Enum.max_by(accumulator.category_stats, fn {_category, revenue} -> revenue end)
      else
        {"N/A", 0.0}
      end

    %{
      total_sales: Float.round(accumulator.total_sales, 2),
      unique_products: MapSet.size(accumulator.unique_products),
      average_discount: calculate_average(accumulator.discounts),
      top_product: "#{top_product} (#{top_quantity} units)",
      top_category: "#{top_category} ($#{Float.round(top_revenue, 2)})",
      date_range: "#{accumulator.earliest_date} to #{accumulator.latest_date}",
      processed_lines: accumulator.processed_lines_count,
      errors_found: length(accumulator.error_lines),
      error_details: Enum.reverse(accumulator.error_lines)
    }
  end

  # ----------------------------------------------------------------------
  # METRICS FINALIZATION
  # ----------------------------------------------------------------------

  @doc false
  # Calculate total sales from a product.
  defp calculate_discounted_sale_total(%{price: price, quantity: quantity, discount: discount}) do
    price * quantity * (1 - discount / 100)
  end

  # Calculates the average of a list of numbers; returns 0.0 for empty lists.
  defp calculate_average([]), do: 0.0
  defp calculate_average(numbers), do: Enum.sum(numbers) / length(numbers)
end
