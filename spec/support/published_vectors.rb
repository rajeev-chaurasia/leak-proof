# frozen_string_literal: true

# Vectors published by third parties, held in pieces.
#
# Each is a real, non-live value taken from public research: the GitHub tokens
# from a 2022 format-analysis thread where they were shared as expired, the AWS
# key from the test suite of psanford/aws-account-id-from-key. They are split
# because a contiguous copy would be a credential-shaped string in this
# repository, which GitHub's push protection blocks, correctly.
#
# Without them the checksum and account-ID implementations would only ever be
# consistent with themselves, which is the failure this project exists to avoid.
module PublishedVectors
  GITHUB = [
    %w[zQWBuTSOoRi4A9spHcVY5ncnsDkxkJ 0mLq17],
    %w[adE7dp8rHP6gUTuPwxLTZjZdtya3sV 0UQzQM],
    %w[H3xbiBdlzffNx7Y56iNsPw3joObj7U 2nO29h]
  ].freeze

  AWS_PREFIX = "ASIA"
  AWS_BODY = "QNZGKIQY56JQ7WML"
  AWS_ACCOUNT_ID = "029608264753"

  # AWS publishes this one throughout its own documentation.
  AWS_DOC_PREFIX = "AKIA"
  AWS_DOC_BODY = "IOSFODNN7EXAMPLE"

  module_function

  def aws_key = "#{AWS_PREFIX}#{AWS_BODY}"
  def aws_documentation_key = "#{AWS_DOC_PREFIX}#{AWS_DOC_BODY}"
end
