defmodule FileProcessorWeb.DonutComponentTest do
  use FileProcessorWeb.ConnCase, async: true
  import Phoenix.LiveViewTest

  test "calcula correctamente los segmentos del SVG para diferentes estados" do
    stats = %{total: 10, warnings: 2, errors: 3}

    html = render_component(FileProcessorWeb.DonutComponent,
      id: "test-donut",
      display_stats: stats,
      percentage: 50.0
    )

    assert html =~ "30.0 70.0"
    assert html =~ "20.0 80.0"
    assert html =~ "50%"
  end
end
