defmodule EthereumABI do
  @moduledoc """
  Documentation for the Application Binary Interface (ABI) of the
  Ethereum Virtual Machine (or EVM).

  Generally, the Ethereum ABI describes how to take binary Ethereum and transform
  it to or from types that Solidity understands.
  """

  @doc """
  Encodes the given data into the function signature or tuple signature.

  ## Examples

      iex> [50, <<1::160>> |> :binary.decode_unsigned]
      ...> |> EthereumABI.encode_input("baz(uint,address)")
      ...> |> Base.encode16(case: :lower)
      "a291add600000000000000000000000000000000000000000000000000000000000000320000000000000000000000000000000000000000000000000000000000000001"

      iex> EthereumABI.encode_input([9999], "baz(uint8)")
      ** (RuntimeError) Data overflow encoding uint, data `9999` cannot fit in 8 bits

      iex> [{50, <<1::160>> |> :binary.decode_unsigned}]
      ...> |> EthereumABI.encode_input("((uint,address))")
      ...> |> Base.encode16(case: :lower)
      "00000000000000000000000000000000000000000000000000000000000000320000000000000000000000000000000000000000000000000000000000000001"

      iex> [{"Ether Token"}]
      ...> |> EthereumABI.encode_input("((string))")
      ...> |> Base.encode16(case: :lower)
      "0000000000000000000000000000000000000000000000000000000000000020000000000000000000000000000000000000000000000000000000000000000b457468657220546f6b656e000000000000000000000000000000000000000000"
  """
  def encode_input(data, function_signature) do
    EthereumABI.TypeEncoder.encode(
      data,
      EthereumABI.FunctionSelector.parse(function_signature)
    )
  end

  @doc """
  Decodes the given data based on the function signature.

  ## Examples

      iex> "00000000000000000000000000000000000000000000000000000000000000320000000000000000000000000000000000000000000000000000000000000001"
      ...> |> Base.decode16!(case: :lower))
      ...> |> EthereumABI.decode("baz(uint,address)")
      [50, <<1::160>>]

  """
  def decode_input(data, function_signature) do
    selector = EthereumABI.FunctionSelector.parse(function_signature, preload: :method_id)
    _selector_sig = selector.method_id
    <<_selector_sig::binary-size(4)>> <> data_without_method_id = data
    EthereumABI.TypeDecoder.decode_input(data_without_method_id, selector)
  end

  @doc """
  Decodes the given EVM output data based on the provided return type.

  ## Examples

      iex> "0000000000000000000000000000000000000000000000000000000000000001"
      ...> |> Base.decode16!(case: :lower)
      ...> |> EthereumABI.decode_output("bool")
      [true]

      iex> "00000000000000000000000000000000000000000000000000000000000000200000000000000000000000000000000000000000000000000000000000000000"
      ...> |> Base.decode16!(case: :lower)
      ...> |> EthereumABI.decode_output("(address[])")
      [{[]}]

      iex> "0000000000000000000000000000000000000000000000000000000000000020000000000000000000000000000000000000000000000000000000000000000b457468657220546f6b656e000000000000000000000000000000000000000000"
      ...> |> Base.decode16!(case: :lower)
      ...> |> EthereumABI.decode_output("(string)")
      [{"Ether Token"}]
  """
  def decode_output(data, return_type) do
    function_signature = if String.contains?(return_type, "->") do
      return_type
    else
      "() -> #{return_type}"
    end

    EthereumABI.TypeDecoder.decode_output(
      data,
      EthereumABI.FunctionSelector.parse(function_signature)
    )
  end
end
