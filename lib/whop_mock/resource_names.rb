# frozen_string_literal: true

module WhopMock
  module ResourceNames
    ACCOUNT_LINK = "account_link"
    CHECKOUT_CONFIGURATION = "checkout_configuration"
    COMPANY = "company"
    COURSE_LESSON_INTERACTION = "course_lesson_interaction"
    DISPUTE = "dispute"
    DISPUTE_ALERT = "dispute_alert"
    ENTRY = "entry"
    EVENT = "event"
    FEE_MARKUP = "fee_markup"
    INVOICE = "invoice"
    LEDGER_ACCOUNT = "ledger_account"
    MEMBER = "member"
    MEMBERSHIP = "membership"
    PAYMENT = "payment"
    PAYMENT_METHOD = "payment_method"
    PAYMENT_TOKEN = "payment_token"
    PAYOUT_ACCOUNT = "payout_account"
    PAYOUT_METHOD = "payout_method"
    PLAN = "plan"
    PROMO_CODE = "promo_code"
    PRODUCT = "product"
    REFUND = "refund"
    RESOLUTION_CENTER_CASE = "resolution_center_case"
    SETUP_INTENT = "setup_intent"
    TOPUP = "topup"
    TRANSFER = "transfer"
    VERIFICATION = "verification"
    WEBHOOK = "webhook"
    WITHDRAWAL = "withdrawal"

    module_function

    def normalize(value)
      value.to_s
    end
  end
end
