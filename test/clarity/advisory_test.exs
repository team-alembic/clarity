defmodule Clarity.AdvisoryTest do
  use ExUnit.Case, async: true

  alias Clarity.Advisory

  describe "from_osv/1" do
    test "splits one record into one advisory per affected Hex package" do
      osv = %{
        "id" => "GHSA-xxxx",
        "summary" => "Boom",
        "aliases" => ["CVE-2026-0001"],
        "references" => [%{"type" => "WEB", "url" => "https://example.com/a"}],
        "database_specific" => %{"severity" => "HIGH"},
        "affected" => [
          %{"package" => %{"ecosystem" => "Hex", "name" => "mdex"}},
          %{"package" => %{"ecosystem" => "Hex", "name" => "mdex_native"}},
          %{"package" => %{"ecosystem" => "npm", "name" => "ignored"}}
        ]
      }

      advisories = Advisory.from_osv(osv)

      assert Enum.map(advisories, & &1.package) == ["mdex", "mdex_native"]
      assert Enum.all?(advisories, &(&1.id == "GHSA-xxxx"))
      assert hd(advisories).severity == "HIGH"
      assert hd(advisories).summary == "Boom"
      assert hd(advisories).references == ["https://example.com/a"]
      assert hd(advisories).aliases == ["CVE-2026-0001"]
    end

    test "falls back to details when summary is absent" do
      osv = %{
        "id" => "GHSA-yyyy",
        "details" => "Long details",
        "affected" => [%{"package" => %{"ecosystem" => "Hex", "name" => "foo"}}]
      }

      assert [%Advisory{summary: "Long details"}] = Advisory.from_osv(osv)
    end
  end

  describe "affects_version?/2" do
    @spec advisory(keyword()) :: Advisory.t()
    defp advisory(ranges: ranges), do: %Advisory{id: "x", package: "p", ranges: ranges}
    defp advisory(versions: versions), do: %Advisory{id: "x", package: "p", versions: versions}

    test "matches an explicit version" do
      assert Advisory.affects_version?(advisory(versions: ["1.0.0", "1.0.1"]), "1.0.1")
      refute Advisory.affects_version?(advisory(versions: ["1.0.0"]), "1.0.1")
    end

    test "matches an introduced/fixed range, half-open" do
      adv = advisory(ranges: [%{"events" => [%{"introduced" => "1.0.0"}, %{"fixed" => "1.2.0"}]}])

      refute Advisory.affects_version?(adv, "0.9.0")
      assert Advisory.affects_version?(adv, "1.0.0")
      assert Advisory.affects_version?(adv, "1.1.9")
      refute Advisory.affects_version?(adv, "1.2.0")
      refute Advisory.affects_version?(adv, "1.3.0")
    end

    test "treats introduced 0 as from the beginning" do
      adv = advisory(ranges: [%{"events" => [%{"introduced" => "0"}, %{"fixed" => "0.13.2"}]}])

      assert Advisory.affects_version?(adv, "0.13.1")
      refute Advisory.affects_version?(adv, "0.13.2")
    end

    test "matches last_affected ranges inclusively" do
      adv = advisory(ranges: [%{"events" => [%{"introduced" => "1.0.0"}, %{"last_affected" => "1.2.0"}]}])

      assert Advisory.affects_version?(adv, "1.2.0")
      refute Advisory.affects_version?(adv, "1.2.1")
    end

    test "an open range (no fixed) does not match without last_affected" do
      adv = advisory(ranges: [%{"events" => [%{"introduced" => "1.0.0"}]}])
      refute Advisory.affects_version?(adv, "1.5.0")
    end

    test "unparseable versions fail closed" do
      adv = advisory(ranges: [%{"events" => [%{"introduced" => "0"}, %{"fixed" => "2.0.0"}]}])
      refute Advisory.affects_version?(adv, "not-a-version")
    end
  end
end
