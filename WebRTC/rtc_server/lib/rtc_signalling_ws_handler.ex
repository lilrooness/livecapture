defmodule RtcServer.Signalling.WSHandler do
  @behaviour :cowboy_websocket

  @sdpOffer ~s(v=0\no=- 4540707994449696028 2 IN IP4 127.0.0.1\ns=-\nt=0 0\na=group:BUNDLE data\na=msid-semantic: WMS\nm=application 9 DTLS/SCTP 5000\nc=IN IP4 0.0.0.0\na=ice-lite\na=ice-pwd:asd88fgpdd777uzjYhagZg\na=ice-ufrag:8hhY\na=fingerprint:sha-256 F2:B8:CE:D8:3C:E0:98:2B:BD:61:2D:3F:77:01:61:76:0A:A7:02:50:53:EF:3E:4E:37:22:40:68:0B:06:A7:C8\na=setup:actpass\na=mid:data\na=sctpmap:9999 webrtc-datachannel 1024\na=candidate:0 1 UDP 2130706431 192.168.8.110 9999 typ host\n)

  def init(request, _state) do
    state = %{registry_key: request.path}

    {:cowboy_websocket, request, state}
  end

  def websocket_init(state) do
    Registry.RTCServer
    |> Registry.register(state.registry_key, {})

    send(
      self(),
      {:send,
       Jason.encode!(%{
         payload: %{
           sdp: @sdpOffer
         }
       })}
    )

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

  def websocket_info({:send, text}, state) do
    {:reply, {:text, text}, state}
  end
end
