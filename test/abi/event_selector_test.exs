defmodule ABI.EventSelectorTest do
  use ExUnit.Case, async: true
  doctest ABI.EventSelector

  @selector_source """
  Transfer(
    address indexed _from,
    address owner,
    string indexed _to,
    uint256 indexed _tokenId,
    uint256 tokenId
  )
  """

  @test_event %{
    topics: [
      "39ce25cb9eb8e7d68c58325d6493b7f9347812d615d19e33dc399364e792a813",
      "0000000000000000000000000000000000000000000000000000000000000000",
      "0000000000000000000000000f6b591443fcf9cb5245f80cf852872b59a75c22",
      "0000000000000000000000000000000000000000000000000000000000024451"
    ],

    data: <<
      "0000000000000000000000003aa80b5a79854cdbb7b65f6c851946ce1d781c7c",
      "000000000000000000000000000000000000000000000000000000000002444b"
    >>
  }

  @data0_as_address <<58, 168, 11, 90, 121, 133, 76, 219, 183, 182, 95, 108, 133, 25, 70, 206, 29, 120, 28, 124>>

  test "event selector can be parsed" do
    selector =
      @selector_source
      |> ABI.Parser.parse!(as: :selector, bindings: true)
      |> ABI.EventSelector.new(with_signature: true)

    topics = Enum.map(@test_event.topics, &Base.decode16!(&1, case: :lower))
    data = Base.decode16!(@test_event.data, case: :lower)

    {{decoded_topics, decoded_data}, decoded_captures} = ABI.EventSelector.decode_event(selector, topics, data, capture: :all_names)

    assert decoded_topics == [
      selector,
      <<0::160>>,
      %ABI.DecodedIndexedValue{type: :string, hash: Enum.at(topics, 2)},
      148561
    ]

    assert decoded_data == [
      @data0_as_address,
      148555
    ]

    assert Map.new(decoded_captures) == %{
     "_from" => <<0::160>>,
     "_to" => %ABI.DecodedIndexedValue{type: :string, hash: Enum.at(topics, 2)},
     "_tokenId" => 148561,
     "owner" => @data0_as_address,
     "tokenId" => 148555
   }
  end
end
