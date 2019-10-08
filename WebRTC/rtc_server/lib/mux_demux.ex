defmodule RtcServer.MuxerDemuxer do
  use GenServer

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

  def start_link() do
    GenServer.start_link(__MODULE__, [], name: __MODULE__)
  end

  @impl true
  def init([]) do
    {:ok, socket} = :gen_udp.open(9999, [{:active, true}, :binary])

    message_type = <<0x01::integer-size(16)>>
    message_length = <<0x00::integer-size(16)>>
    magic_cookie = <<0x2112A442::integer-size(32)>>
    transaction_id = <<0x2112A4422112A4422112A400::integer-size(96)>>

    :gen_udp.send(
      socket,
      {192, 168, 43, 148},
      5000,
      <<message_type::binary, message_length::binary, magic_cookie::binary,
        transaction_id::binary>>
    )

    {:ok, %__MODULE__{multiplexed_socket: socket}}
  end

  @impl true
  def handle_info(data, state) do
    IO.inspect(data, label: :info_data)
    {:noreply, state}
  end

  # def recv(:cast, {:send, data}, state = %__MODULE__{multiplexed_socket: socket}) do
  #   :socket.send(socket, data)
  #   {:next_event, {:internal, {:recv, @udp_mtu}}, state}
  # end

  # def recv(:internal, {:recv, mtu_size}, state = %__MODULE__{multiplexed_socket: socket}) do
  #   {:ok, data} = :socket.recv(socket, mtu_size, :nowait)
  #   {:next_event, {:internal, {:recv, @udp_mtu}}, state}
  # end
end
