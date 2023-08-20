defmodule LightsOutGameWeb.Board do
  use LightsOutGameWeb, :live_view
  use OrdMap

  def mount(params, _session, socket) do
    IO.puts(Enum.map_join(params, ", ", fn {key, val} -> ~s{#{key}: #{val}} end))
    size_x = Map.get(params, "x", "5") |> String.to_integer()
    size_y = Map.get(params, "y", "5") |> String.to_integer()

    grid_style =
      "grid-template-columns: repeat(#{size_x}, minmax(0, 1fr)); grid-template-rows: repeat(#{size_y}, minmax(0, 1fr));"

    grid = for x <- 0..(size_x - 1), y <- 0..(size_y - 1), into: [], do: {{x, y}, false}
    grid = OrdMap.new(grid)
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
    |> Map.values()
    |> Enum.all?(fn light -> !light end)
  end
end
