defmodule FileProcessor.CsvProcessor do
  @moduledoc """
  Specialized processor for CSV files, delegated by `FileProcessor`.
  Extracts data and calculates metrics using `NimbleCSV`.
  Calculated metrics:
  - total sales
  - unique products
  - average discount
  - top product
  - top category
  - date range
  - processed lines
  """

  # Defines the parse settings: "," as the separator and "°" as the escape character
  NimbleCSV.define(MyParser, separator: ",", escape: "°")

  @doc """
  Entry point for the module.
  Processes a CSV file and returns a map of calculated metrics.

  ## Data flow
  1. File stream
  2. Line parsing
  3. Data accumulation
  4. Metrics calculation.
  """
  def process(path) do
    lines =
      path
      |> File.stream!()
      |> MyParser.parse_stream()
      |> Enum.to_list()

    metrics =
      set_initial_accumulator()
      |> process_lines(lines, 1)
      |> finalize_metrics()

    {:ok, metrics}
  end

  @doc false
  # Initializes the data accumulator with default values for CSV metrics.
  defp set_initial_accumulator() do
    %{
      total_sales: 0.0,
      products: MapSet.new(),
      discounts: [],
      product_stats: %{},  # %{"product_name" => total_quantity}
      category_stats: %{}, # %{"category" => total_sales}
      min_date: nil,
      max_date: nil,
      processed_lines: 0,
      error_lines: []
    }
  end

  # --- RECURSIVE LOGIC ---

  @doc false
  # Iterates over the list of lines, parsing them using the parse_line/1 function.
  defp process_lines(accumulator, [], _line_number), do: accumulator
  defp process_lines(accumulator, [first_line | rest], line_number) do
    new_accumulator =
      case parse_line(first_line) do
        {:ok, data} -> update_accumulator(accumulator, data)

        {:error, reason} ->
          Map.update!(accumulator, :error_lines, fn errors ->
            ["line #{line_number}: #{reason}" | errors]
          end)
      end

    process_lines(new_accumulator, rest, line_number + 1)
  end

  @doc false
  # Updates the accumulator data with information from a successfully parsed line.
  # Calculates the sales amount (applying discounts) before adding it to the totals.
  defp update_accumulator(accumulator, data) do
    sale_amount = calculate_sale_total(data)

    %{
      accumulator |
      total_sales: accumulator.total_sales + sale_amount,
      products: MapSet.put(accumulator.products, data.product),
      discounts: [data.discount | accumulator.discounts],
      product_stats: Map.update(accumulator.product_stats, data.product, data.quantity, &(&1 + data.quantity)),
      category_stats: Map.update(accumulator.category_stats, data.category, sale_amount, &(&1 + sale_amount)),
      min_date: update_min_date(accumulator.min_date, data.date),
      max_date: update_max_date(accumulator.max_date, data.date),
      processed_lines: accumulator.processed_lines + 1
    }
  end

  # --- DATA PARSING AND VALIDATION ---

  @doc false
  # Transforms a list of strings into a structured map with data types.
  # Performs type and range validations for price, quantity, and discount
  defp parse_line([date, product, category, price, quantity, discount]) do
    with {:ok, date} <- validate_date(date),
         {:ok, price} <- validate_float(price, "Invalid price"),
         {:ok, quantity} <- validate_int(quantity, "Invalid quantity"),
         {:ok, discount} <- validate_discount(discount) do
      {:ok,
        %{
          date: date,
          product: product,
          category: category,
          price: price,
          quantity: quantity,
          discount: discount
        }
      }
    else
      {:error, reason} -> {:error, reason}
    end
  end

  # Error clause for lines with corrupt lines.
  defp parse_line(_), do: {:error, "Corrupt line (missing columns)"}

  # --- HELPERS ---

  @doc false
  # Calculate total sales from a product.
  defp calculate_sale_total(%{price: price, quantity: quantity, discount: discount}) do
    price * quantity * (1 - discount / 100)
  end

  @doc false
  # Validates prices are positive.
  defp validate_float(value, msg) do
    case Float.parse(value) do
      {num, _} when num >= 0 -> {:ok, num}
      _ -> {:error, msg}
    end
  end

  @doc false
  # Validates discount is between 0 and 100%.
  defp validate_discount(value) do
    case Float.parse(value) do
      {num, _} when num >= 0 and num <= 100 -> {:ok, num}
      _ -> {:error, "Discount out of range (0-100)"}
    end
  end

  @doc false
  # Validates quantity is positive.
  defp validate_int(value, msg) do
    case Integer.parse(value) do
      {num, _} when num > 0 -> {:ok, num}
      _ -> {:error, msg}
    end
  end

  defp validate_date(date) do
    if String.match?(date, ~r/^\d{4}-\d{2}-\d{2}$/), do: {:ok, date}, else: {:error, "Invalid date format"}
  end

  @doc false
  # Date comparison helpers for string formats.
  defp update_min_date(nil, new_date), do: new_date
  defp update_min_date(current, new_date), do: if(new_date < current, do: new_date, else: current)

  defp update_max_date(nil, new_date), do: new_date
  defp update_max_date(current, new_date), do: if(new_date > current, do: new_date, else: current)

  # --- METRICS CALCULATION ---

  @doc false
  # Uses the accumulator data to calculate metrics and stores them in a map with
  # data that the Report module can convert into a string.
  defp finalize_metrics(accumulator) do
    # Search the top quantity product
    {top_product, top_quantity} =
      if map_size(accumulator.product_stats) > 0,
      do: Enum.max_by(accumulator.product_stats, fn {_product, quantity} -> quantity end),
      else: {"N/A", 0}

    # Search the top revenue category
    {top_category, top_revenue} =
      if map_size(accumulator.category_stats) > 0,
      do: Enum.max_by(accumulator.category_stats, fn {_category, revenue} -> revenue end),
      else: {"N/A", 0.0}

    %{
      total_sales: Float.round(accumulator.total_sales, 2),
      unique_products: MapSet.size(accumulator.products),
      average_discount: calculate_average(accumulator.discounts),
      top_product: "#{top_product} (#{top_quantity} units)",
      top_category: "#{top_category} ($#{Float.round(top_revenue, 2)})",
      date_range: "#{accumulator.min_date} to #{accumulator.max_date}",
      processed_lines: accumulator.processed_lines,
      errors_found: length(accumulator.error_lines),
      error_details: Enum.reverse(accumulator.error_lines)
    }
  end

  # Calculates the average of a list of numbers; returns 0.0 for empty lists.
  defp calculate_average([]), do: 0.0
  defp calculate_average(list), do: Enum.sum(list) / length(list)

end
