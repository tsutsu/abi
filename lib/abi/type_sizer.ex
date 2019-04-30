defmodule ABI.TypeSizer do
  import Bitwise, only: [{:"<<<", 2}]

  @unboundedSize (1 <<< 31)

  def encoded_size_range(function_selector) do
    do_size(function_selector.types, {0, 0})
  end

  def raw_size(types) do
    do_size(types, {0, 0})
  end

  defp do_size([], {min, max}) do
    if max >= @unboundedSize do
      {min, :infinity}
    else
      {min, max}
    end
  end
  defp do_size([type | remaining_types], {min, max}) do
    {type_min, type_max} = size_of_type(type)
    do_size(remaining_types, {min + type_min, max + type_max})
  end

  defp size_of_type({:uint, size_in_bits}) when rem(size_in_bits, 8) == 0 do
    static_size = div(size_in_bits, 8)
    {static_size, static_size}
  end
  defp size_of_type({:int, size_in_bits}) when rem(size_in_bits, 8) == 0 do
    static_size = div(size_in_bits, 8)
    {static_size, static_size}
  end
  defp size_of_type({:ufixed, size_in_bits, _precision}) when rem(size_in_bits, 8) == 0 do
    static_size = div(size_in_bits, 8)
    {static_size, static_size}
  end
  defp size_of_type({:fixed, size_in_bits, _precision}) when rem(size_in_bits, 8) == 0 do
    static_size = div(size_in_bits, 8)
    {static_size, static_size}
  end
  defp size_of_type(:address), do: {20, 20}
  defp size_of_type(:function), do: {24, 24}
  defp size_of_type(:bool), do: {1, 1}
  defp size_of_type(:string), do: {32, @unboundedSize}
  defp size_of_type(:bytes), do: {32, @unboundedSize}
  defp size_of_type({:bytes, size}) when size >= 1 and size <= 32, do: {size, size}

  defp size_of_type({:tuple, types}) do
    Enum.reduce(types, {0, 0}, fn type, {size_min_acc, size_max_acc} ->
      {el_size_min, el_size_max} = size_of_type(type)

      el_dynamic_overhead = case ABI.FunctionSelector.is_dynamic?(type) do
        true  -> 64
        false -> 32
      end

      {
        size_min_acc + el_dynamic_overhead + el_size_min,
        size_max_acc + el_dynamic_overhead + el_size_max
      }
    end)
  end

  defp size_of_type({:array, type, element_count}) do
    {per_member_size_min, per_member_size_max} = size_of_type(type)

    per_member_dynamic_overhead = case ABI.FunctionSelector.is_dynamic?(type) do
      true  -> 64
      false -> 32
    end

    {
      (per_member_size_min + per_member_dynamic_overhead) * element_count,
      (per_member_size_max + per_member_dynamic_overhead) * element_count
    }
  end

  defp size_of_type({:array, _type}), do: {32, @unboundedSize}

  defp size_of_type({:indexed, inner_type}) do
    case ABI.FunctionSelector.is_potentially_dynamic?(inner_type) do
      true  -> {32, 32}
      false -> size_of_type(inner_type)
    end
  end

  defp size_of_type({:seq, inner_type}), do: size_of_type(inner_type)
  defp size_of_type({:binding, inner_type, _name}), do: size_of_type(inner_type)

  defp size_of_type(els) do
    raise "Unsupported type: #{inspect(els)}"
  end
end
