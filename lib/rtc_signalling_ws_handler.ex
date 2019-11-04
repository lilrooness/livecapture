defmodule RtcServer.Signalling.WSHandler do
  @behaviour :cowboy_websocket

  @sdpOffer ~s(v=0\no=- 4540707994449696028 2 IN IP4 127.0.0.1\ns=-\nt=0 0\na=group:BUNDLE data\na=msid-semantic: WMS\na=ice-lite\na=ice-pwd:asd88fgpdd777uzjYhagZg\na=ice-ufrag:8hhY\nm=application 9 DTLS/SCTP 9999\nc=IN IP4 127.0.0.1\na=candidate:0 1 UDP 2130706431 127.0.0.1 9999 typ host\na=fingerprint:sha-256 61:3A:01:36:17:7C:CA:C9:21:65:27:53:C2:B6:F4:72:DC:6C:28:66:34:69:36:67:03:90:D1:50:4B:4B:02:D5\na=setup:actpass\na=mid:data\na=sctpmap:9999 webrtc-datachannel 1024\n)

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
        # RtcServer.MuxerDemuxer.start_link(my_sdp, peer_sdp)
        dtls_port = 9876
        RtcServer.WebRTCSessionSup.start_session(my_sdp, peer_sdp, dtls_port)

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
        {String.to_atom(key), ""}
      else
        ["a", "ice-lite"] ->
          {:a, "ice-lite"}

        ["a", value] ->
          [inner_k, inner_v] = value |> String.split(":", parts: 2)
          {String.to_atom(inner_k), String.strip(inner_v)}

        [key, value] ->
          {String.to_atom(key), String.strip(value)}
      end
    end)
  end
end
