defmodule Clarity.Vertex.UtilTest do
  use ExUnit.Case, async: true

  alias Clarity.Vertex.Root
  alias Clarity.Vertex.Util
  alias Demo.Accounts.User

  describe inspect(&Util.id/2) do
    test "generates ID with module vertex type and module part" do
      assert Util.id(Clarity.Vertex.Module, [String]) == "module:string"
      assert Util.id(Acme.Vertex.Other, [String]) == "acme-vertex-other:string"
    end

    test "generates ID with resource vertex type and module part" do
      assert Util.id(Clarity.Vertex.Ash.Resource, [User]) ==
               "ash-resource:demo-accounts-user"
    end

    test "generates ID with multiple parts including atoms" do
      assert Util.id(Clarity.Vertex.Ash.Attribute, [User, :email]) ==
               "ash-attribute:demo-accounts-user:email"
    end

    test "generates ID with string parts" do
      assert Util.id(Root, ["custom"]) == "root:custom"
    end

    test "generates ID with mixed atom and string parts" do
      assert Util.id(Root, ["custom", :part]) == "root:custom:part"
      assert Util.id(Root, ["custom", :"part.with/slash"]) == "root:custom:part-with-slash"
    end

    test "handles non-module atoms correctly" do
      assert Util.id(Clarity.Vertex.Ash.Action, [User, :create]) ==
               "ash-action:demo-accounts-user:create"
    end

    test "handles domain vertex type" do
      assert Util.id(Clarity.Vertex.Ash.Domain, [Demo.Accounts.Domain]) ==
               "ash-domain:demo-accounts-domain"
    end

    test "handles relationship vertex type" do
      assert Util.id(Clarity.Vertex.Ash.Relationship, [User, :posts]) ==
               "ash-relationship:demo-accounts-user:posts"
    end

    test "handles calculation vertex type" do
      assert Util.id(Clarity.Vertex.Ash.Calculation, [User, :full_name]) ==
               "ash-calculation:demo-accounts-user:full-name"
    end

    test "handles aggregate vertex type" do
      assert Util.id(Clarity.Vertex.Ash.Aggregate, [User, :post_count]) ==
               "ash-aggregate:demo-accounts-user:post-count"
    end

    test "handles Phoenix endpoint vertex type" do
      assert Util.id(Clarity.Vertex.Phoenix.Endpoint, [DemoWeb.Endpoint]) ==
               "phoenix-endpoint:demo-web-endpoint"
    end

    test "handles Phoenix router vertex type" do
      assert Util.id(Clarity.Vertex.Phoenix.Router, [DemoWeb.Router]) ==
               "phoenix-router:demo-web-router"
    end

    test "handles Spark DSL vertex type" do
      assert Util.id(Clarity.Vertex.Spark.Dsl, [Ash.Resource.Dsl]) ==
               "spark-dsl:ash-resource-dsl"
    end

    test "handles Spark Extension vertex type" do
      assert Util.id(Clarity.Vertex.Spark.Extension, [Ash.Resource]) ==
               "spark-extension:ash-resource"
    end

    test "handles Spark Entity vertex type" do
      assert Util.id(Clarity.Vertex.Spark.Entity, [Ash.Resource.Dsl, :attribute]) ==
               "spark-entity:ash-resource-dsl:attribute"
    end

    test "handles Spark Section vertex type" do
      assert Util.id(Clarity.Vertex.Spark.Section, [Ash.Resource.Dsl, :attributes]) ==
               "spark-section:ash-resource-dsl:attributes"
    end
  end
end
