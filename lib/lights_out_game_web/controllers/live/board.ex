defmodule LightsOutGameWeb.Board do
  use LightsOutGameWeb, :live_view
  use OrdMap

  def mount(params, _session, socket) do
    init_str = Map.get(params, "init", "5_5_3X1O6X1O6X2O6X")
    parts = String.split(init_str, "_")

    [size_x, size_y, grid_string | _] = parts
    size_x = size_x |> String.to_integer()
    size_y = size_y |> String.to_integer()

    grid_string = uncompress_string(grid_string)

    IO.puts(grid_string)

    grid_style =
      "grid-template-columns: repeat(#{size_x}, minmax(0, 1fr)); grid-template-rows: repeat(#{size_y}, minmax(0, 1fr));"

    grid = string_to_grid(grid_string, size_x, size_y)
    # level1 = %{{2, 0} => true, {2, 2} => true, {2, 4} => true}
    # grid = Map.merge(grid, level1)
    {:ok,
     assign(socket,
       grid: grid,
       grid_style: grid_style,
       win: false,
       max_x: size_x - 1,
       max_y: size_y - 1
     )}
  end

  def handle_event("toggle", %{"x" => str_x, "y" => str_y}, socket) do
    already_won = socket.assigns.win

    case already_won do
      true ->
        {:noreply, socket}

      false ->
        grid = socket.assigns.grid
        grid_x = String.to_integer(str_x)
        grid_y = String.to_integer(str_y)
        max_x = socket.assigns.max_x
        max_y = socket.assigns.max_y

        updated_grid =
          find_adjacent_tiles(grid_x, grid_y, max_x, max_y)
          |> Enum.reduce(OrdMap.new(%{}), fn point, acc ->
            OrdMap.put(acc, point, !OrdMap.get(grid, point))
          end)
          |> then(fn toggled_grid -> OrdMap.merge(grid, toggled_grid) end)

        win = check_win(updated_grid)

        socket = assign(socket, grid: updated_grid, win: win)

        case win do
          true -> {:noreply, push_event(socket, "gameover", %{win: win})}
          false -> {:noreply, socket}
        end
    end
  end

  defp find_adjacent_tiles(x, y, max_x, max_y) do
    IO.puts(max_x)
    prev_x = Kernel.max(0, x - 1)
    prev_y = Kernel.max(0, y - 1)
    next_x = Kernel.min(max_x, x + 1)
    next_y = Kernel.min(max_y, y + 1)

    [{x, y}, {prev_x, y}, {next_x, y}, {x, prev_y}, {x, next_y}]
  end

  defp check_win(grid) do
    grid
    |> OrdMap.values()
    |> Enum.all?(fn light -> !light end)
  end

  defp grid_to_string(x, y, grid) do
    grid_string =
      grid
      |> OrdMap.values()
      |> Enum.each(fn val -> if val, do: "O", else: "X" end)

    "#{x}_#{y}_" <> grid_string
  end

  defp string_to_grid(grid_string, size_x, size_y) do
    values =
      grid_string
      |> String.graphemes()
      |> Enum.map(fn g -> if g == "O", do: true, else: false end)

    grid = for x <- 0..(size_x - 1), y <- 0..(size_y - 1), into: [], do: {{x, y}, false}
    grid = [grid, values] |> Enum.zip_with(fn [{{x, y}, _oldVal}, newVal] -> {{x, y}, newVal} end)
    OrdMap.new(grid)
  end

  defp compress_string(uncompressed_grid_string) do
    uncompressed_grid_string
    |> (&(&1 <> "E")).()
    |> String.graphemes()
    |> Enum.reduce([], fn val, acc ->
      case acc do
        [] ->
          [[val]]

        [h | t] ->
          count = Integer.to_string(Enum.count(h))
          latestVal = List.first(h)
          compressedSeries = Enum.reverse([count | [latestVal]])

          cond do
            val == "E" ->
              [compressedSeries | t]

            val == latestVal ->
              [[val | h] | t]

            true ->
              [[val] | [compressedSeries | t]]
          end
      end
    end)
    |> List.flatten()
    |> Enum.reverse()
    |> List.to_string()
  end

  defp uncompress_string(compressed_grid_string) do
    Regex.scan(~r/[0-9]+[XO]+/, compressed_grid_string)
    |> List.flatten()
    |> Enum.map(fn group -> String.graphemes(group) |> Enum.reverse() end)
    |> Enum.reverse()
    |> Enum.map(fn [h | t] ->
      char = h
      n = t |> Enum.reverse() |> List.to_string() |> String.to_integer()
      String.duplicate(char, n)
    end)
    |> Enum.reverse()
    |> List.to_string()
  end
end
