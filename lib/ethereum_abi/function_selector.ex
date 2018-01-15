defmodule EthereumABI.FunctionSelector do
  @moduledoc """
  Module to help parse the ABI function signatures, e.g.
  `my_function(uint64, string[])`.
  """

  require Integer

  @type type ::
    {:uint, integer()} |
    :bool

  @type t :: %__MODULE__{
    function: String.t,
    types: [type],
    returns: type
  }

  defstruct [:method_id, :function, :types, :returns]

  @doc """
  Decodes a function selector to an `EthereumABI.FunctionSelector` struct.

  ## Options

  If `{:preload, :method_id}` is passed in `opts`, the constructed `EthereumABI.FunctionSelector` struct will be passed through `preload_method_id/1`.

  ## Examples

      iex> EthereumABI.FunctionSelector.parse("bark(uint256,bool)")
      %EthereumABI.FunctionSelector{
        function: "bark",
        types: [
          {:uint, 256},
          :bool
        ]
      }

      iex> EthereumABI.FunctionSelector.parse("growl(uint,address,string[])")
      %EthereumABI.FunctionSelector{
        function: "growl",
        types: [
          {:uint, 256},
          :address,
          {:array, :string}
        ]
      }

      iex> EthereumABI.FunctionSelector.parse("rollover()")
      %EthereumABI.FunctionSelector{
        function: "rollover",
        types: []
      }

      iex> EthereumABI.FunctionSelector.parse("pet(address[])")
      %EthereumABI.FunctionSelector{
        function: "pet",
        types: [
          {:array, :address}
        ]
      }

      iex> EthereumABI.FunctionSelector.parse("paw(string[2])")
      %EthereumABI.FunctionSelector{
        function: "paw",
        types: [
          {:array, :string, 2}
        ]
      }

      iex> EthereumABI.FunctionSelector.parse("scram(uint256[])")
      %EthereumABI.FunctionSelector{
        function: "scram",
        types: [
          {:array, {:uint, 256}}
        ]
      }

      iex> EthereumABI.FunctionSelector.parse("shake((string))")
      %EthereumABI.FunctionSelector{
        function: "shake",
        types: [
          {:tuple, [:string]}
        ]
      }
  """
  def parse(signature, opts \\ []) do
    {:ok, tokens, _} = signature |> String.to_charlist |> :ethereum_abi_lexer.string
    {:ok, struct_parts} = :ethereum_abi_parser.parse(tokens)
    function_selector = struct!(EthereumABI.FunctionSelector, struct_parts)

    if opts[:preload] == :method_id do
      preload_method_id(function_selector)
    else
      function_selector
    end
  end

  @doc """
  Encodes a function call signature.

  This function is also called as the implementation of the `List.Chars` protocol for `EthereumABI.FunctionSelector` structs.

  ## Examples

      iex> selector = %EthereumABI.FunctionSelector{
      ...>   function: "bark",
      ...>   types: [
      ...>     {:uint, 256},
      ...>     :bool,
      ...>     {:array, :string},
      ...>     {:array, :string, 3},
      ...>     {:tuple, [{:uint, 256}, :bool]}
      ...>   ]
      ...> }
      %EthereumABI.FunctionSelector{
        function: "bark",
        types: [
          {:uint, 256},
          :bool,
          {:array, :string},
          {:array, :string, 3},
          {:tuple, [{:uint, 256}, :bool]}
        ]
      }

      iex> EthereumABI.FunctionSelector.as_string(selector)
      "bark(uint256,bool,string[],string[3],(uint256,bool))"

      iex> to_string(selector)
      "bark(uint256,bool,string[],string[3],(uint256,bool))"

      iex> "\#{selector}"
      "bark(uint256,bool,string[],string[3],(uint256,bool))"
  """
  def as_string(function_selector), do: as_string(function_selector, :canonical)

  @doc false
  def as_string(function_selector, :canonical) do
    input_types_decl = Enum.map(function_selector.types, &encode_type/1) |> Enum.join(",")
    "#{function_selector.function}(#{input_types_decl})"
  end
  def as_string(function_selector, :extended) do
    input_ts = Enum.map(function_selector.types, &encode_type/1)
    return_ts = Enum.map(function_selector.returns, &encode_type/1)

    selector = "#{function_selector.function}(#{Enum.join(input_ts, ",")})"

    case return_ts do
      [] -> selector
      [return_type] -> "#{selector} -> #{return_type}"
      return_types -> "#{selector} -> (#{Enum.join(return_types, ",")})"
    end
  end

  @doc """
  Calculates and returns the EVM method ID—a hashed representation of the function name and parameter types.

  This function is called automatically by `EthereumABI.TypeEncoder.encode/1` to embed the method ID into the input data. You likely will not need to call this function yourself.

  If the function name has not been set in the `EthereumABI.FunctionSelector` struct, the returned method ID will always be `<<>>`. When such a method ID is used in `EthereumABI.TypeEncoder.encode/1`, the resulting encoded data will contain only the type-serialized inputs, without a leading method ID. This is useful for calling the default method of a contract.

  If the method ID has been stored into the struct by `preload_method_id/1`, it is simply returned instead. Performance of batch calls to `EthereumABI.TypeEncoder.encode/1` can be increased by preloading the method ID of the `EthereumABI.FunctionSelector` struct passed.

  ## Examples

      iex> EthereumABI.FunctionSelector.method_id(%EthereumABI.FunctionSelector{
      ...>   function: "bark",
      ...>   types: [:bool]
      ...> })
      <<67, 233, 196, 163>>

  A different function name changes the method ID:

      iex> EthereumABI.FunctionSelector.method_id(%EthereumABI.FunctionSelector{
      ...>   function: "boof",
      ...>   types: [:bool]
      ...> })
      <<117, 141, 173, 194>>

  A different parameter type list changes the method ID:

      iex> EthereumABI.FunctionSelector.method_id(%EthereumABI.FunctionSelector{
      ...>   function: "bark",
      ...>   types: [:uint256]
      ...> })
      <<137, 47, 68, 233>>

  A different return type does **not** change the method ID:

      iex> EthereumABI.FunctionSelector.method_id(%EthereumABI.FunctionSelector{
      ...>   function: "bark",
      ...>   types: [:bool],
      ...>   returns: :uint256
      ...> })
      <<67, 233, 196, 163>>

  A preloaded method ID is returned, even if incorrect:

      iex> EthereumABI.FunctionSelector.method_id(%EthereumABI.FunctionSelector{
      ...>   function: "bark",
      ...>   types: [:bool],
      ...>   method_id: <<0, 0, 0, 0>>
      ...> })
      <<0, 0, 0, 0>>
  """
  @spec method_id(%__MODULE__{}) :: binary()
  def method_id(%__MODULE__{method_id: <<_::binary-size(4)>> = id}), do: id
  def method_id(%__MODULE__{function: nil}), do: <<>>
  def method_id(%__MODULE__{} = function_selector), do: derive_method_id(function_selector)

  @doc """
  Calculates the EVM method ID as in `method_id/1`, and stores the result into the `EthereumABI.FunctionSelector` struct.

  Preloading the EVM method ID avoids redundant calculation when an `EthereumABI.FunctionSelector` will be repeatedly used.

  ## Examples

      iex> selector = %EthereumABI.FunctionSelector{
      ...>   function: "bark",
      ...>   types: [:bool]
      ...> }
      %EthereumABI.FunctionSelector{
        function: "bark",
        types: [:bool]
      }

      iex> EthereumABI.FunctionSelector.method_id(selector)
      <<67, 233, 196, 163>>

      iex> warmed_selector = EthereumABI.FunctionSelector.preload_method_id(selector)
      %EthereumABI.FunctionSelector{
        function: "bark",
        types: [:bool],
        method_id: <<67, 233, 196, 163>>
      }

      iex> EthereumABI.FunctionSelector.method_id(warmed_selector) # uses cached value
      <<67, 233, 196, 163>>
  """
  def preload_method_id(%__MODULE__{method_id: <<_::binary-size(4)>>} = function_selector), do: function_selector
  def preload_method_id(%__MODULE__{method_id: nil} = function_selector) do
    %{function_selector | method_id: derive_method_id(function_selector)}
  end

  @spec derive_method_id(%__MODULE__{}) :: binary()
  defp derive_method_id(%__MODULE__{function: nil}), do: ""
  defp derive_method_id(%__MODULE__{} = function_selector) do
    # Encode selector e.g. "baz(uint32,bool)" and take keccak
    kec = as_string(function_selector) |> ExthCrypto.Hash.Keccak.kec()

    # Take first four bytes
    <<init::binary-size(4), _rest::binary>> = kec

    # That's our method id
    init
  end

  defp encode_type(nil), do: nil
  defp encode_type({:int, size}), do: "int#{size}"
  defp encode_type({:uint, size}), do: "uint#{size}"
  defp encode_type(:address), do: "address"
  defp encode_type(:bool), do: "bool"
  defp encode_type({:fixed, element_count, precision}), do: "fixed#{element_count}x#{precision}"
  defp encode_type({:ufixed, element_count, precision}), do: "ufixed#{element_count}x#{precision}"
  defp encode_type({:bytes, size}), do: "bytes#{size}"
  defp encode_type(:function), do: "function"

  defp encode_type({:array, type, element_count}), do: "#{encode_type(type)}[#{element_count}]"

  defp encode_type(:bytes), do: "bytes"
  defp encode_type(:string), do: "string"
  defp encode_type({:array, type}), do: "#{encode_type(type)}[]"

  defp encode_type({:tuple, types}) do
    encoded_types = Enum.map(types, &encode_type/1)
    "(#{Enum.join(encoded_types, ",")})"
  end

  defp encode_type(els), do: "Unsupported type: #{inspect els}"
end

defimpl String.Chars, for: EthereumABI.FunctionSelector do
  defdelegate to_string(function_selector), to: EthereumABI.FunctionSelector, as: :as_string
end
