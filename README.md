# ABI

The [Application Binary Interface](https://solidity.readthedocs.io/en/develop/abi-spec.html) (ABI) of Solidity describes how to transform binary data to types which the Solidity programming language understands. For instance, if we want to call a function `bark(uint32,bool)` on a Solidity-created contract `contract Dog`, what `data` parameter do we pass into our Ethereum transaction? This project allows us to encode such function calls.

## Installation

If [available in Hex](https://hex.pm/docs/publish), the package can be installed
by adding `abi` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:ethereum_abi, "~> 0.1.8"}
  ]
end
```

Documentation can be generated with [ExDoc](https://github.com/elixir-lang/ex_doc)
and published on [HexDocs](https://hexdocs.pm). Once published, the docs can
be found at [https://hexdocs.pm/abi](https://hexdocs.pm/abi).

## Usage

### Encoding

To encode a function call, pass the ABI spec and the data to pass in to `EthereumABI.encode/1`.

```elixir
iex> EthereumABI.encode_input([50, <<1::160>> |> :binary.decode_unsigned], "baz(uint,address)")
<<162, 145, 173, 214, 0, 0, 0, 0, 0, 0, 0, 0, ...>
```

Then, you can construct an Ethereum transaction with that data, e.g.

```elixir
# Blockchain comes from `Exthereum.Blockchain`, see below.
iex> %Blockchain.Transaction{
...> # ...
...> data: <<162, 145, 173, 214, 0, 0, 0, 0, 0, 0, 0, 0, ...>
...> }
```

That transaction can then be sent via JSON-RPC or DevP2P to execute the given function.

### Decoding

Decoding of input is generally the opposite of encoding. To precisely reverse the above:

```elixir
iex> ("a291add600000000000000000000000000000000000000000000000000000000000000320000000000000000000000000000000000000000000000000000000000000001"
...> |> Base.decode16!(case: :lower)
...> |> EthereumABI.decode_input("baz(uint,address)"))
[50, <<0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1>>]
```

Called like this, the method signature is checked for a match to its hash embedded in the input data.

If you have raw input data (data without the method signature hash "header" embedded), you can decode it by passing a function signature to `EthereumABI.decode_input/2` consisting only of the types, without the function name. Decoding the same as above:

```elixir
iex> ("00000000000000000000000000000000000000000000000000000000000000320000000000000000000000000000000000000000000000000000000000000001"
...> |> Base.decode16!(case: :lower)
...> |> EthereumABI.decode_input("(uint,address)"))
[50, <<0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1>>]
```

Decoding of output data (data returned by the EVM) is similar to decoding headerless input data, but with the expectation that there will only be one type passed, without parentheses. (A parenthesized return-type here would be interpreted as a tuple type.)

```elixir
iex> ("0000000000000000000000000000000000000000000000000000000000000032"
...> |> Base.decode16!(case: :lower)
...> |> EthereumABI.decode_output("uint"))
50

iex> ("00000000000000000000000000000000000000000000000000000000000000320000000000000000000000000000000000000000000000000000000000000001"
...> |> Base.decode16!(case: :lower)
...> |> EthereumABI.decode_output("(uint,address)"))
{50, <<0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1>>}
```

### Using compound function signatures

Rather than keeping track of input and output signatures separately, you can create a compound function signature by joining the input types and the return type with an arrow (`->`). Such a string will work for both encoding/decoding inputs (which uses only the left side of the signature), and for decoding outputs (which uses only the right side.)

```elixir
iex> ([50, true]
...> |> EthereumABI.encode_input("foo(uint,bool) -> uint")
...> |> EthereumABI.decode_input("foo(uint,bool) -> uint"))
[50, true]

iex> ("0000000000000000000000000000000000000000000000000000000000000032"
...> |> Base.decode16!(case: :lower)
...> |> EthereumABI.decode_output("foo(uint,bool) -> uint"))
50

## Support

Currently supports:

  * [X] `uint<M>`
  * [X] `int<M>`
  * [X] `address`
  * [X] `uint`
  * [X] `bool`
  * [ ] `fixed<M>x<N>`
  * [ ] `ufixed<M>x<N>`
  * [ ] `fixed`
  * [ ] `bytes<M>`
  * [ ] `function`
  * [X] `<type>[M]`
  * [X] `bytes`
  * [X] `string`
  * [X] `<type>[]`
  * [X] `(T1,T2,...,Tn)` (* currently ABI parsing doesn't parse tuples with multiple elements)

# Docs

* [Solidity ABI](https://solidity.readthedocs.io/en/develop/abi-spec.html)
* [Solidity Docs](https://solidity.readthedocs.io/)
* [Solidity Grammar](https://github.com/ethereum/solidity/blob/develop/docs/grammar.txt)
* [Exthereum Blockchain](https://github.com/exthereum/blockchain)
