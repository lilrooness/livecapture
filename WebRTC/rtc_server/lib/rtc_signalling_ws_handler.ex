defmodule RtcServer.Signalling.WSHandler do
  @behaviour :cowboy_websocket

  @sdpOffer ~s(v=0\no=- 4540707994449696028 2 IN IP4 127.0.0.1\ns=-\nt=0 0\na=group:BUNDLE data\na=msid-semantic: WMS\nm=application 9 DTLS/SCTP 9999\nc=IN IP4 0.0.0.0\na=ice-lite\na=ice-pwd:asd88fgpdd777uzjYhagZg\na=ice-ufrag:8hhY\na=fingerprint:sha-256 F2:B8:CE:D8:3C:E0:98:2B:BD:61:2D:3F:77:01:61:76:0A:A7:02:50:53:EF:3E:4E:37:22:40:68:0B:06:A7:C8\na=setup:actpass\na=mid:data\na=sctpmap:9999 webrtc-datachannel 1024\na=candidate:0 1 UDP 2130706431 127.0.0.1 9999 typ host\n)

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

  def websocket_handle({:text, json}, state) do
    # IO.inspect(limit: :infinity)
    Jason.decode(json)
    |> case do
      {:ok, %{"sdp" => sdp_string}} ->
        peer_sdp = process_sdp(sdp_string)

        my_sdp = process_sdp(@sdpOffer)
        RtcServer.MuxerDemuxer.start_link(my_sdp, peer_sdp)

      {:ok, candidate} ->
        IO.inspect(candidate, label: :candidate)

      _ ->
        IO.inspect(json, label: :raw)
    end

    {:ok, state}
  end

  def websocket_info({:send, text}, state) do
    {:reply, {:text, text}, state}
  end

  defp process_sdp(sdp_string) do
    sdp_string
    |> String.split("\n")
    |> Enum.map(fn line ->
      with [key] <- String.split(line, "=") do
        {key, ""}
      else
        ["a", "ice-lite"] ->
          {"a", "ice-lite"}

        ["a", value] ->
          [inner_k, inner_v] = value |> String.split(":", parts: 2)
          {inner_k, String.strip(inner_v)}

        [key, value] ->
          {key, String.strip(value)}
      end
    end)
  end
end
