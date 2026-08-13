# MV_CREDIT_CARD_INFO_TEMPLATE

Overrides the template used to assemble the credit-card information string that
Interchange encrypts at checkout. Reach for it when you need the encrypted
card block to contain a different set or arrangement of fields.

**Scope:** catalog (`catalog.cfg`)

## Syntax

    Variable  MV_CREDIT_CARD_INFO_TEMPLATE  template-text

The value is a template string with `{FIELD}` placeholders for the card fields.
Default: unset (the built-in template is used).

## Description

`build_cc_info` assembles the card data that gets encrypted for storage or
transmission. When `MV_CREDIT_CARD_INFO_TEMPLATE` is set, its value is used as
the template; otherwise the built-in default is used, which is a tab-joined
line of:

    {MV_CREDIT_CARD_TYPE}
    {MV_CREDIT_CARD_NUMBER}
    {MV_CREDIT_CARD_EXP_MONTH}/{MV_CREDIT_CARD_EXP_YEAR}
    {MV_CREDIT_CARD_CVV2}

The placeholder names correspond to the submitted `mv_credit_card_*` form
fields (see [mv-form-variables](mv-form-variables.md)).

## Examples

Store only type, number, and expiry (tab-separated):

    Variable  MV_CREDIT_CARD_INFO_TEMPLATE  {MV_CREDIT_CARD_TYPE}	{MV_CREDIT_CARD_NUMBER}	{MV_CREDIT_CARD_EXP_MONTH}/{MV_CREDIT_CARD_EXP_YEAR}

## See also

[mv-form-variables](mv-form-variables.md), the
[payments](../guides/payments.md) and [security](../guides/security.md) guides.

## Source

Consumed in `lib/Vend/Order.pm` (`build_cc_info`) via
`$::Variable->{MV_CREDIT_CARD_INFO_TEMPLATE}`.
