# SPEC-008 - A reviewed portfolio can always be exported

Audit items: R-16
Status: accepted

## Problem
The PDF export drew text with Prawn's built-in fonts, which can only draw Windows-1252 characters and raise on any
other. The line shown for an assessor override contained an arrow, and candidate quotes are arbitrary text (symbols,
other scripts, emoji). So the export answered 500 for every portfolio the assessor had reviewed (an override exists),
and for any quote outside Windows-1252, leaving only the JSON export.

## Rules
1. The PDF export never fails because of the text it contains. A character the PDF font cannot draw is replaced by `?`.
2. The JSON export is the lossless one: it keeps the original text.
3. The override line reads "AI: L3, assessor override: L4" (no symbol outside the font).

## Acceptance criteria
Given a completed portfolio with an assessor override
When the assessor exports it as PDF
Then the answer is 200 and the body is a PDF.

Given a candidate quote containing symbols, CJK text and an emoji
When the assessor exports the portfolio as PDF
Then the answer is 200, the unsupported characters appear as `?`, and the JSON export still holds the original quote.

## Out of scope
Embedding a Unicode font so that other scripts are drawn instead of replaced (the sensible next step).

## Checks
api/spec/requests/api/v1/portfolios_spec.rb ("PDF export of a portfolio with an assessor override and text the PDF font cannot draw")
