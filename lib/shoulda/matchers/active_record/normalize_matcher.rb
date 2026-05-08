module Shoulda
  module Matchers
    module ActiveRecord
      # The `normalize` matcher is used to ensure attribute normalizations
      # are transforming attribute values as expected.
      #
      # Take this model for example:
      #
      #     class User < ActiveRecord::Base
      #       normalizes :email, with: -> email { email.strip.downcase }
      #     end
      #
      # You can use `normalize` providing an input and defining the expected
      # normalization output:
      #
      #     # RSpec
      #     RSpec.describe User, type: :model do
      #       it do
      #         should normalize(:email).from(" ME@XYZ.COM\n").to("me@xyz.com")
      #       end
      #     end
      #
      #     # Minitest (Shoulda)
      #     class User < ActiveSupport::TestCase
      #       should normalize(:email).from(" ME@XYZ.COM\n").to("me@xyz.com")
      #     end
      #
      # You can use `normalize` to test multiple attributes at once:
      #
      #     class User < ActiveRecord::Base
      #       normalizes :email, :handle, with: -> value { value.strip.downcase }
      #     end
      #
      #     # RSpec
      #     RSpec.describe User, type: :model do
      #       it do
      #         should normalize(:email, :handle).from(" Example\n").to("example")
      #       end
      #     end
      #
      #     # Minitest (Shoulda)
      #     class User < ActiveSupport::TestCase
      #       should normalize(:email, :handle).from(" Example\n").to("example")
      #     end
      #
      # If the normalization accepts nil values with the `apply_to_nil` option,
      # you just need to use `.from(nil).to("Your expected value here")`.
      #
      #     class User < ActiveRecord::Base
      #       normalizes :name, with: -> name { name&.titleize || 'Untitled' },
      #         apply_to_nil: true
      #     end
      #
      #     # RSpec
      #     RSpec.describe User, type: :model do
      #       it { should normalize(:name).from("jane doe").to("Jane Doe") }
      #       it { should normalize(:name).from(nil).to("Untitled") }
      #     end
      #
      #     # Minitest (Shoulda)
      #     class User < ActiveSupport::TestCase
      #       should normalize(:name).from("jane doe").to("Jane Doe")
      #       should normalize(:name).from(nil).to("Untitled")
      #     end
      #
      # If you extracted normalization logic to a named callable, you can ensure
      # the model uses that callable:
      #
      #     class User < ActiveRecord::Base
      #       NameNormalizer = -> name { name.to_s.strip.downcase }
      #
      #       normalizes :name, with: NameNormalizer
      #     end
      #
      #     # RSpec
      #     RSpec.describe User, type: :model do
      #       it { should normalize(:name).with(User::NameNormalizer) }
      #     end
      #
      #     # Minitest (Shoulda)
      #     class User < ActiveSupport::TestCase
      #       should normalize(:name).with(User::NameNormalizer)
      #     end
      #
      # @return [NormalizeMatcher]
      #
      def normalize(*attributes)
        if attributes.empty?
          raise ArgumentError, 'need at least one attribute'
        else
          NormalizeMatcher.new(*attributes)
        end
      end

      # @private
      class NormalizeMatcher
        attr_reader :attributes, :from_value, :to_value, :failure_message,
          :failure_message_when_negated

        def initialize(*attributes)
          @attributes = attributes
          @from_value_set = false
          @to_value_set = false
        end

        def description
          description = "normalize #{attributes.to_sentence(last_word_connector: ' and ')}"

          if normalization_value_assertion?
            description << " from ‹#{from_value.inspect}› to ‹#{to_value.inspect}›"
          end

          if expected_normalizer
            description << " with ‹#{expected_normalizer.inspect}›"
          end

          description
        end

        def from(value)
          @from_value = value
          @from_value_set = true

          self
        end

        def to(value)
          @to_value = value
          @to_value_set = true

          self
        end

        def with(callable)
          @expected_normalizer = callable

          self
        end

        def matches?(subject)
          attributes.all? { |attribute| attribute_matches?(subject, attribute) }
        end

        def does_not_match?(subject)
          attributes.all? { |attribute| attribute_does_not_match?(subject, attribute) }
        end

        private

        def attribute_matches?(subject, attribute)
          if normalization_value_assertion? && !normalize_attribute?(subject, attribute)
            @failure_message = build_failure_message(
              attribute,
              subject.class.normalize_value_for(attribute, from_value),
            )
            return false
          end

          return true if expected_normalizer_matches?(subject, attribute)

          @failure_message = build_failure_message_for_normalizer(
            attribute,
            normalizer_for_attribute(subject, attribute),
          )
          false
        end

        def attribute_does_not_match?(subject, attribute)
          if normalization_value_assertion? && normalize_attribute?(subject, attribute)
            @failure_message_when_negated = build_failure_message_when_negated(attribute)
            return false
          end

          return true unless expected_normalizer_matches?(subject, attribute)

          @failure_message_when_negated = build_failure_message_when_negated_for_normalizer(
            attribute,
          )
          false
        end

        attr_reader :expected_normalizer

        def normalization_value_assertion?
          @from_value_set || @to_value_set
        end

        def normalize_attribute?(subject, attribute)
          subject.class.normalize_value_for(attribute, from_value) == to_value
        end

        def expected_normalizer_matches?(subject, attribute)
          expected_normalizer.nil? || normalizer_for_attribute(subject, attribute) == expected_normalizer
        end

        def normalizer_for_attribute(subject, attribute)
          type = subject.class.type_for_attribute(attribute)

          if type.respond_to?(:normalizer)
            type.normalizer
          end
        end

        def build_failure_message(attribute, attribute_value)
          %(
            Expected to normalize #{attribute.inspect} from ‹#{from_value.inspect}› to
            ‹#{to_value.inspect}› but it was normalized to ‹#{attribute_value.inspect}›
          ).squish
        end

        def build_failure_message_for_normalizer(attribute, actual_normalizer)
          %(
            Expected to normalize #{attribute.inspect} with ‹#{expected_normalizer.inspect}›
            but it was configured with ‹#{actual_normalizer.inspect}›
          ).squish
        end

        def build_failure_message_when_negated(attribute)
          %(
            Expected to not normalize #{attribute.inspect} from ‹#{from_value.inspect}› to
            ‹#{to_value.inspect}› but it was normalized
          ).squish
        end

        def build_failure_message_when_negated_for_normalizer(attribute)
          %(
            Expected to not normalize #{attribute.inspect} with
            ‹#{expected_normalizer.inspect}› but it was configured with that callable
          ).squish
        end
      end
    end
  end
end
