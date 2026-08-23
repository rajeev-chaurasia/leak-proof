# frozen_string_literal: true

require "digest"

module Leakproof
  module Filter
    # Values every vendor prints in its own documentation, so they appear in far
    # more repositories than any real credential ever will.
    #
    # Held as digests rather than literals, for the same reason detectors declare
    # a shape instead of a sample: a list of credential-shaped strings committed
    # here would be blocked on push, and rightly so. The comments keep the list
    # auditable without carrying the material.
    module KnownDummies
      DIGESTS = {
        # AWS documentation example secret access key
        "78314b11be2e581549ac1c4f616563fad3fdf0c3b71678f6e2299182080e0598" =>
          "aws-docs-secret-access-key",
        # AWS documentation example access key ID
        "1a5d44a2dca19669d72edf4c4f1c27c4c1ca4b4408fbb17f6ce4ad452d78ddb3" =>
          "aws-docs-access-key-id",
        # AWS documentation alternate access key ID
        "c6ea27c534f993d31f0aef882e3d200e7b87470c379ae79c8f9b19d3bd363dc9" =>
          "aws-docs-access-key-id-alt",
        # Stripe documentation example live secret key
        "78a08441f4314f0a2833cfe58c62e555a162264206982cda39f6804f5048f570" =>
          "stripe-docs-secret-key",
        # Stripe documentation example test secret key
        "2cafc0970149a84f3b9e62eaf169f36f59907a3b3e31f7b82e68c69cd27f7326" =>
          "stripe-docs-test-key",
        # Stripe documentation example publishable key
        "b1471f544ceeea31333bde7e1ecbaad6eac0d4a749412ad29bd66ef895b81c6b" =>
          "stripe-docs-publishable-key",
        # Stripe documentation example key body
        "153a182586451358014e3142089118ce38f6c7dc7c79014d3fa40b57f80b4aab" =>
          "stripe-docs-key-body",
        # Google documentation example API key
        "1021ad463a161d69de63ef74566407b9ed012deb6d9306a4bc7183544c84350c" =>
          "google-docs-api-key",
        # Azurite published development account key
        "0011cc25eb4320717494d2703e8cba85743e71b500283c21c8b88147992f9059" =>
          "azurite-dev-account-key",
        # Azurite published development account name
        "4b2dd836d664f91a377630253bf8017041701dab7e2f468522dcc96d015e9e2e" =>
          "azurite-dev-account-name",
        # jwt.io canonical demo signature
        "051d093c4bdedbf23f905ad01d9c6111414d54e2170e1d7f76657c4e76e3e65b" =>
          "jwt-io-demo-signature"
      }.freeze

      module_function

      def match(value)
        DIGESTS[Digest::SHA256.hexdigest(value.to_s)]
      end

      def known?(value)
        !match(value).nil?
      end
    end
  end
end
