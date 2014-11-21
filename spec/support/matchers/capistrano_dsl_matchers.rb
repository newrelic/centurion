RSpec::Matchers.define :have_key_and_value do |expected_key, expected_value|
  match do |actual|
    actual.env[actual.current_environment].has_key?(expected_key.to_sym) && (actual.fetch(expected_key.to_sym) == expected_value)
  end

  failure_message do |actual|
    "expected that #{actual.env[actual.current_environment].keys.inspect} would include #{expected_key.inspect} with value #{expected_value.inspect}"
  end

  failure_message_when_negated do |actual|
    "expected that #{actual.env[actual.current_environment].keys.join(', ')} would not include #{expected_key.inspect} with value #{expected_value.inspect}"
  end
end
