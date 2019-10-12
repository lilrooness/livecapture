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
  def handle_info(input, state) do
    {:udp, _port, _saddr, _sport, data} = input
    IO.inspect(data, label: :info_data)

    case data do
      <<0x0001::integer-size(16), length::integer-size(16), 0x2112A442::integer-size(32),
        transaction_id::integer-size(96), attrs::binary>> ->
        # Logger.info("STUN BINDING REQUEST: ATTRS: #{attrs}")
        StunPacketAttrs.parse(attrs, length)

      <<0x0101::integer-size(16), length::integer-size(16), 0x2112A442::integer-size(16),
        transaction_id::integer-size(96), attrs::binary>> ->
        Logger.info("STUN BINDING SUCCESS: ATTRS: #{attrs} ")
    end

    {:noreply, state}
  end
end

defmodule StunPacketAttrs do
  require Logger

  defstruct [
    :username,
    :ice_controlled,
    :ice_controller,
    :priority,
    :message_integrity,
    :fingerprint
  ]

  def parse(attrs, _length) do
    attrs_list = [username_attr | _rest] = seperate_binary(attrs)
    IO.inspect(username_attr, label: "username_attr")
  end

  def seperate_binary(attrs) do
    seperate_binary(attrs, [])
  end

  def seperate_binary(<<>>, attrs_list) do
    attrs_list
  end

  def seperate_binary(attrs_binary, attrs_list) do
    <<attr_type::integer-size(16), attr_length::integer-size(16), rest_including_attr::binary>> =
      attrs_binary

    # attrs are padded to the nearest multiple of 4 bytes
    padding_bytes =
      case rem(attr_length, 4) do
        0 -> 0
        r -> 4 - r
      end

    <<attr::binary-size(attr_length), rest_maybe_including_padding::binary>> = rest_including_attr

    <<_padding::binary-size(padding_bytes), rest::binary>> = rest_maybe_including_padding

    seperate_binary(rest, [{attr_type, attr_length, attr} | attrs_list])
  end
end

defmodule StunUsernameAttr do
  defstruct [
    :length,
    :username,
    :padding
  ]
end

defmodule StunFingerprintAttr do
  defstruct [
    :length,
    :crc_32
  ]
end
