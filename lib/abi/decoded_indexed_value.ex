defmodule ABI.DecodedIndexedValue do
  defstruct [:type, :hash]

  def new(type, hash) do
    %__MODULE__{type: type, hash: hash}
  end
end
