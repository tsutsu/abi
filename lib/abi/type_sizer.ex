defmodule ABI.TypeSizer do
  import Bitwise, only: [{:"<<<", 2}]

  @unboundedSize (1 <<< 31)

  def packed_size_range(%ABI.FunctionSelector{types: types}), do:
    do_size(types, {0, 0}, :packed)
  def packed_size_range(types) when is_list(types), do:
    do_size(types, {0, 0}, :packed)
  def packed_size_range(type), do:
    do_size([type], {0, 0}, :packed)

  def padded_size_range(%ABI.FunctionSelector{types: types}), do:
    do_size(types, {0, 0}, :padded)
  def padded_size_range(types) when is_list(types), do:
    do_size(types, {0, 0}, :padded)
  def padded_size_range(type), do:
    do_size([type], {0, 0}, :padded)

  defp do_size([], {min, max}, _) do
    if max >= @unboundedSize do
      {min, :infinity}
    else
      {min, max}
    end
  end
  defp do_size([type | remaining_types], {min, max}, pad_mode) do
    {type_min, type_max} = size_of_type(type, pad_mode)
    do_size(remaining_types, {min + type_min, max + type_max}, pad_mode)
  end

  @scalar_types [:uint, :int, :ufixed, :fixed]
  @scalar_sizes Enum.to_list(1..32)
  for scalar_type <- @scalar_types, scalar_size <- @scalar_sizes do
    scalar_bit_size = scalar_size * 8
    defp size_of_type({unquote(scalar_type), unquote(scalar_bit_size)}, :packed) do
      {unquote(scalar_size), unquote(scalar_size)}
    end
    defp size_of_type({unquote(scalar_type), unquote(scalar_bit_size)}, :padded) do
      {32, 32}
    end
  end

  defp size_of_type(:address, :packed), do: {20, 20}
  defp size_of_type(:address, :padded), do: {32, 32}

  defp size_of_type(:function, :packed), do: {24, 24}
  defp size_of_type(:function, :padded), do: {32, 32}

  defp size_of_type(:bool, :packed), do: {1, 1}
  defp size_of_type(:bool, :padded), do: {32, 32}

  defp size_of_type(:string, :packed), do: {0, @unboundedSize}
  defp size_of_type(:string, :padded), do: {32, @unboundedSize}

  defp size_of_type(:bytes, :packed), do: {0, @unboundedSize}
  defp size_of_type(:bytes, :padded), do: {32, @unboundedSize}

  defp size_of_type({:bytes, size}, :packed) when size >= 1 and size <= 32, do: {size, size}
  defp size_of_type({:bytes, size}, :padded) when size >= 1 and size <= 32, do: {32, 32}

  # no packed encoding for tuple
  defp size_of_type({:tuple, types}, :padded) do
    Enum.reduce(types, {0, 0}, fn type, {size_min_acc, size_max_acc} ->
      {el_size_min, el_size_max} = size_of_type(type, :padded)

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

  defp size_of_type({:array, type, element_count}, :packed) do
    {per_member_size_min, per_member_size_max} = size_of_type(type, :padded)

    {
      per_member_size_min * element_count,
      per_member_size_max * element_count
    }
  end
  defp size_of_type({:array, type, element_count}, :padded) do
    {per_member_size_min, per_member_size_max} = size_of_type(type, :padded)

    per_member_dynamic_overhead = case ABI.FunctionSelector.is_dynamic?(type) do
      true  -> 64
      false -> 32
    end

    {
      (per_member_size_min + per_member_dynamic_overhead) * element_count,
      (per_member_size_max + per_member_dynamic_overhead) * element_count
    }
  end

  defp size_of_type({:array, _type}, :packed), do: {0, @unboundedSize}
  defp size_of_type({:array, _type}, :padded), do: {32, @unboundedSize}

  # no packed encoding for indexed
  defp size_of_type({:indexed, inner_type}, :padded) do
    case ABI.FunctionSelector.is_potentially_dynamic?(inner_type) do
      true  -> {32, 32}
      false -> size_of_type(inner_type, :padded)
    end
  end

  # no packed encoding for seq
  defp size_of_type({:seq, inner_type}, :padded), do:
    size_of_type(inner_type, :padded)

  # no packed encoding for bindings
  defp size_of_type({:binding, inner_type, _name}, :padded), do:
    size_of_type(inner_type, :padded)

  defp size_of_type(els, pad_mode) do
    raise "Unsupported #{pad_mode} type: #{inspect(els)}"
  end
end
