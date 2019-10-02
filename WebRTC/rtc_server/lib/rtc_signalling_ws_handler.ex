defmodule RtcServer.Signalling.WSHandler do
  @behaviour :cowboy_websocket

  def init(request, _state) do
    state = %{registry_key: request.path}

    {:cowboy_websocket, request, state}
  end

  def websocket_init(state) do
    Registry.RTCServer
    |> Registry.register(state.registry_key, {})

    {:ok, state}
  end

  # def websocket_handle({:text, json}, state) do
  #   payload = Jason.decode!(json)
  #   message = payload["data"]["message"] |> IO.inspect()

  #   Registry.RTCServer
  #   |> Registry.dispatch(state.registry_key, fn entries ->
  #     for {pid, _} <- entries do
  #       if pid != self() do
  #         Process.send(pid, message, [])
  #       end
  #     end
  #   end)

  #   {:reply, {:text, "YOU: " <> message}, state}
  # end

  def websocket_handle({:text, json}, state) do
    # IO.inspect(limit: :infinity)
    Jason.decode(json)
    |> case do
      {:ok, %{"payload" => %{"sdp" => sdp}}} ->
        IO.puts(sdp)

      {:ok, candidate} ->
        IO.inspect(candidate)

      _ ->
        IO.inspect(json)
    end

    # IO.puts(data)

    {:ok, state}
  end

  def websocket_info(info, state) do
    {:reply, {:text, info}, state}
  end
end
