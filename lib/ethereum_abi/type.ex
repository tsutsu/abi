defmodule EthereumABI.Type do
  @moduledoc false

  @doc false
  def is_dynamic?(:bytes), do: true
  def is_dynamic?(:string), do: true
  def is_dynamic?({:array, _type}), do: true
  def is_dynamic?({:array, _type, 0}), do: false
  def is_dynamic?({:array, type, _length}), do: is_dynamic?(type)
  def is_dynamic?({:tuple, types}), do: Enum.any?(types, &is_dynamic?/1)
  def is_dynamic?(_), do: false
end
