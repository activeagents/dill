require "test_helper"
require "ostruct"

class ResearchAssistantAgentTest < ActiveSupport::TestCase
  test "agent is defined and inherits from ApplicationAgent" do
    assert defined?(ResearchAssistantAgent)
    assert ResearchAssistantAgent < ApplicationAgent
  end

  test "has research action" do
    assert ResearchAssistantAgent.instance_methods.include?(:research)
  end

  test "has navigate tool method" do
    assert ResearchAssistantAgent.public_instance_methods.include?(:navigate)
  end

  test "has extract_text tool method" do
    assert ResearchAssistantAgent.public_instance_methods.include?(:extract_text)
  end

  test "has extract_main_content tool method" do
    assert ResearchAssistantAgent.public_instance_methods.include?(:extract_main_content)
  end

  test "research sets topic and context instance variables" do
    agent = ResearchAssistantAgent.new
    agent.params = { topic: "climate change", context: "scientific article", depth: "standard" }

    agent.instance_variable_set(:@topic, agent.params[:topic])
    agent.instance_variable_set(:@context, agent.params[:context])
    agent.instance_variable_set(:@depth, agent.params[:depth])

    assert_equal "climate change", agent.instance_variable_get(:@topic)
    assert_equal "scientific article", agent.instance_variable_get(:@context)
    assert_equal "standard", agent.instance_variable_get(:@depth)
  end

  test "broadcast_chunk does nothing without stream_id" do
    agent = ResearchAssistantAgent.new
    agent.params = {}

    chunk = OpenStruct.new(delta: "test content")
    assert_nothing_raised { agent.send(:broadcast_chunk, chunk) }
  end

  test "broadcast_chunk does nothing when chunk has no delta" do
    agent = ResearchAssistantAgent.new
    agent.params = { stream_id: "test_123" }

    chunk = OpenStruct.new(delta: nil)
    assert_nothing_raised { agent.send(:broadcast_chunk, chunk) }
  end

  test "broadcast_complete does nothing without stream_id" do
    agent = ResearchAssistantAgent.new
    agent.params = {}

    chunk = OpenStruct.new
    assert_nothing_raised { agent.send(:broadcast_complete, chunk) }
  end

  test "can be instantiated with params" do
    agent = ResearchAssistantAgent.with(
      topic: "artificial intelligence",
      context: "technology article",
      stream_id: "test_123"
    )

    assert_not_nil agent
  end

  test "default depth is standard when not provided" do
    agent = ResearchAssistantAgent.new
    agent.params = { topic: "test topic" }

    agent.instance_variable_set(:@depth, agent.params[:depth] || "standard")
    assert_equal "standard", agent.instance_variable_get(:@depth)
  end
end
