defmodule LightsOutGameWeb.Board do
  use LightsOutGameWeb, :live_view
  use OrdMap

  def mount(params, _session, socket) do
    init_str = Map.get(params, "init", "5_5_3X1O6X1O6X2O6X")
    parts = String.split(init_str, "_")
    [size_x, size_y, grid_string | _] = parts
    size_x = size_x |> String.to_integer()
    size_y = size_y |> String.to_integer()

    grid_style =
      "grid-template-columns: repeat(#{size_x}, minmax(0, 1fr)); grid-template-rows: repeat(#{size_y}, minmax(0, 1fr));"

    grid = string_to_grid(uncompress_string(grid_string), size_x, size_y)

    board_url =
      LightsOutGameWeb.Endpoint.url() <> "?init=" <> "#{size_x}_#{size_y}_" <> grid_string

    {:ok,
     assign(socket,
       grid: grid,
       grid_style: grid_style,
       win: false,
       size_x: size_x,
       size_y: size_y,
       board_url: board_url
     )}
  end

  def handle_event("toggle", %{"x" => str_x, "y" => str_y}, socket) do
    already_won = socket.assigns.win
    grid = socket.assigns.grid
    size_x = socket.assigns.size_x
    size_y = socket.assigns.size_y

    case already_won do
      true ->
        {:noreply, socket}

      false ->
        grid_x = String.to_integer(str_x)
        grid_y = String.to_integer(str_y)

        updated_grid =
          find_adjacent_tiles(grid_x, grid_y, size_x, size_y)
          |> Enum.reduce(OrdMap.new(%{}), fn point, acc ->
            OrdMap.put(acc, point, !OrdMap.get(grid, point))
          end)
          |> then(fn toggled_grid -> OrdMap.merge(grid, toggled_grid) end)

        board_url =
          LightsOutGameWeb.Endpoint.url() <>
            "?init=" <> gen_init_string(size_x, size_y, updated_grid)

        win = check_win(updated_grid)

        socket = assign(socket, grid: updated_grid, win: win, board_url: board_url)

        case win do
          true -> {:noreply, push_event(socket, "gameover", %{win: win})}
          false -> {:noreply, socket}
        end
    end
  end

  defp find_adjacent_tiles(x, y, size_x, size_y) do
    prev_x = Kernel.max(0, x - 1)
    prev_y = Kernel.max(0, y - 1)
    next_x = Kernel.min(size_x - 1, x + 1)
    next_y = Kernel.min(size_y - 1, y + 1)

    [{x, y}, {prev_x, y}, {next_x, y}, {x, prev_y}, {x, next_y}]
  end

  defp check_win(grid) do
    grid
    |> OrdMap.values()
    |> Enum.all?(fn light -> !light end)
  end

  defp gen_init_string(x, y, grid) do
    "#{x}_#{y}_" <> compress_string(grid_to_string(grid))
  end

  defp grid_to_string(grid) do
    grid
    |> OrdMap.values()
    |> Enum.map(fn val -> if val, do: "O", else: "X" end)
    |> List.to_string()
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
    |> String.graphemes()
    |> Enum.chunk_by(&Function.identity(&1))
    |> Enum.map(&(Integer.to_string(Enum.count(&1)) <> Kernel.hd(&1)))
    |> List.to_string()
  end

  defp uncompress_string(compressed_grid_string) do
    Regex.scan(~r/[0-9]+[XO]+/, compressed_grid_string)
    |> List.flatten()
    |> Enum.map(fn group -> String.graphemes(group) |> Enum.reverse() end)
    |> Enum.map(fn [x | xs] ->
      char = x
      n = xs |> Enum.reverse() |> List.to_string() |> String.to_integer()
      String.duplicate(char, n)
    end)
    |> List.to_string()
  end
end
