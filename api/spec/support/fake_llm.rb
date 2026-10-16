# frozen_string_literal: true

# Stands in for Gemini::HttpClient: returns a canned, already-parsed payload and records the prompts it was given.
class FakeLlm
  attr_reader :prompts

  def initialize(response)
    @response = response
    @prompts = []
  end

  def generate_content(prompt, temperature: nil)
    @prompts << prompt
    @response
  end
end
