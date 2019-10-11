defmodule RtcServer.MuxerDemuxer do
  use GenServer

  require Logger

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

    # :gen_udp.send(
    #   socket,
    #   {10, 249, 65, 117},
    #   9876,
    #   generate_stun_payload(:binding)
    # )

    {:ok, %__MODULE__{multiplexed_socket: socket}}
  end

  def generate_stun_payload(:binding) do
    message_type = <<0x01::integer-size(16)>>
    message_length = <<0x00::integer-size(16)>>
    magic_cookie = <<0x2112A442::integer-size(32)>>
    transaction_id = <<0x4E5469735577704E4B4B7271::integer-size(96)>>

    <<message_type::binary, message_length::binary, magic_cookie::binary, transaction_id::binary>>
  end

  def generate_stun_payload(_type) do
    Logger.error("Does not support generating stun payloads of type #{_type}")
  end

  @impl true
  def handle_info(data, state) do
    IO.inspect(data, label: :info_data)

    case data do
      <<0x0001::integer-size(16), length::integer-size(16), 0x2112A442::integer-size(16),
        transaction_id::integer-size(96), attrs::binary>> ->
        Logger.info("STUN BINDING REQUEST: ATTRS: #{attrs}")

      <<0x0101::integer-size(16), length::integer-size(16), 0x2112A442::integer-size(16),
        transaction_id::integer-size(96), attrs::binary>> ->
        Logger.info("STUN BINDING SUCCESS: ATTRS: #{attrs} ")
    end

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
