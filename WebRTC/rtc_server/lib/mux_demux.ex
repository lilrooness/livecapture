defmodule RtcServer.MuxerDemuxer do
  use GenStateMachine, callback_mode: :state_functions

  defstruct [
    :multiplexed_socket,
    non_muxed_sockets: %{
      stun: nil,
      dtls: nil,
      srtp: nil,
      srtcp: nil
    }
  ]

  @udp_mtu 1460

  def recv(:cast, {:send, data}, state = %__MODULE__{multiplexed_socket: socket}) do
    :socket.send(socket, data)
    {:next_event, {:internal, {:recv, @udp_mtu}}, state}
  end

  def recv(:internal, {:recv, mtu_size}, state = %__MODULE__{multiplexed_socket: socket}) do
    {:ok, data} = :socket.recv(socket, mtu_size, :nowait)
    {:next_event, {:internal, {:recv, @udp_mtu}}, state}
  end
end
