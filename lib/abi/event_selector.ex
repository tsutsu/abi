defmodule ABI.EventSelector do
  @moduledoc """
  Module to help parse the ABI event signatures, e.g.
  `MyEvent(uint64 foo, string[] indexed bar)`.

  Currently a stub; most functionality is implemented in
  `ABI.FunctionSelector`.
  """

  defstruct [:name, :params, :topic_params, :data_params, :signature]

  @doc """
  Converts an `ABI.FunctionSelector` into an event selector.
  """
  def new(%ABI.FunctionSelector{function: event_name, types: params, returns: nil}, opts \\ []) do
    params_by_indexedness = Enum.group_by params, fn
      {:binding, {:indexed, _inner_type}, _name} -> true
      {:indexed, _inner_type} -> true
      _ -> false
    end

    sel = %__MODULE__{
      name: event_name,
      params: params,
      topic_params: Map.get(params_by_indexedness, true, []),
      data_params: Map.get(params_by_indexedness, false, []),
      signature: nil
    }

    if Keyword.get(opts, :with_signature, false) do
      with_signature(sel)
    else
      sel
    end
  end

  @doc """
  Calculates the Keccak256 hash of the canonicalized event selector. This hash appears as
  `topics[0]` of log-event data emitted by this event selector.
  """
  def signature(%__MODULE__{signature: sig}) when is_binary(sig), do: sig
  def signature(%__MODULE__{signature: nil, name: name, params: params}) do
    %ABI.FunctionSelector{function: name, types: params, returns: nil}
    |> ABI.FunctionSelector.encode()
    |> ExthCrypto.Hash.Keccak.kec()
  end

  @doc """
  Updates the event selector with a copy of its signature. It is recommended to pass
  any constructed event selectors through this function when are going to use them
  to decode multiple data items, as it saves manual recalculation of the signature on
  each encode.
  """
  def with_signature(%__MODULE__{signature: nil} = event_selector) do
    %{event_selector | signature: signature(event_selector)}
  end
  def with_signature(%__MODULE__{signature: sig} = event_selector) when is_binary(sig) do
    event_selector
  end

  def named_parameters(%__MODULE__{params: params}) do
    find_bindings(params, 0)
    |> Enum.flat_map(fn
      {name, 0} -> [name]
      {_name, n} when n > 0 -> []
    end)
  end

  def bindings(%__MODULE__{params: params}) do
    find_bindings(params, 0)
  end

  defp find_bindings(param_list, depth) when is_list(param_list) do
    Enum.flat_map(param_list, &find_bindings(&1, depth))
  end
  defp find_bindings({:array, inner_type}, depth), do: find_bindings(inner_type, depth + 1)
  defp find_bindings({:array, inner_type, _size}, depth), do: find_bindings(inner_type, depth + 1)
  defp find_bindings({:tuple, types}, depth), do: find_bindings(types, depth + 1)
  defp find_bindings({:indexed, inner_type}, depth), do: find_bindings(inner_type, depth)
  defp find_bindings({:binding, inner_type, name}, depth) do
    [{name, depth}] ++ find_bindings(inner_type, depth)
  end
  defp find_bindings(_scalar_type, _depth), do: []

  @doc """
  Decodes log event data using the given event selector.
  """
  def decode_event(%__MODULE__{topic_params: topic_params, data_params: data_params} = event_selector, [event_signature | topics], data, opts \\ []) do
    if Keyword.get(opts, :check_signature, true) do
      if event_signature != signature(event_selector) do
        raise ArgumentError, "event/selector signature mismatch"
      end
    end

    {decoded_topics, topic_named_captures} =
      Enum.zip(topics, topic_params)
      |> Enum.map(fn {topic, param} -> ABI.TypeDecoder.decode_raw(topic, [param], capture: :all_names) end)
      |> Enum.unzip()

    decoded_topics = [event_selector] ++ Enum.concat(decoded_topics)
    topic_named_captures = Enum.concat(topic_named_captures)

    {decoded_data, data_named_captures} = ABI.TypeDecoder.decode_raw(data, data_params, capture: :all_names)

    named_captures = topic_named_captures ++ data_named_captures

    case Keyword.fetch(opts, :capture) do
      {:ok, :all_names} -> {{decoded_topics, decoded_data}, named_captures}
      _                 -> {decoded_topics, decoded_data}
    end
  end
end
