#!/usr/bin/env ruby

require "minitest/autorun"
require_relative "pseudo-translate-json.rb"

class TestWordsFromString < Minitest::Test
  def setup
    @data = QuickPT::MyHash.new
  end

  def teardown
    pass
  end

  def test_simple_pt
    @data['key'] = "This is a test."
    expected = {"key"=>"«Thïs ïs ä tést.»"}
    assert_equal(expected, @data.pseudoize_string)
  end

  def test_i18next_var_interpolation
    @data['key'] = "This is a {{really_big}} test."
    expected = {"key"=>"«Thïs ïs ä {{really_big}} tést.»"}
    assert_equal(expected, @data.pseudoize_string)
  end

  def test_i18next_var_interpolation_w_html_escape
    @data['key'] = "This is a {{-really_big}} test."
    expected = {"key"=>"«Thïs ïs ä {{- really_big}} tést.»"}
    assert_equal(expected, @data.pseudoize_string)
  end

  def test_i18next_var_interpolation_w_html_escape_w_space
    @data['key'] = "This is a {{-      really_big}} test."
    expected = {"key"=>"«Thïs ïs ä {{- really_big}} tést.»"}
    assert_equal(expected, @data.pseudoize_string)
  end

  def test_i18next_var_interpolation_w_empty_string
    @data['key'] = ""
    expected = {"key"=>""}
    assert_equal(expected, @data.pseudoize_string)
  end

  def test_two_adjacent_i18next_vars
    @data['key'] = "This is a {{really_big}}test{{really_big}}."
    expected = {"key"=>"«Thïs ïs ä {{really_big}}tést{{really_big}}.»"}
    assert_equal(expected, @data.pseudoize_string)
  end

  def test_two_adjacent_i18next_vars_w_html_escape
    @data['key'] = "This is a {{-really_big}}test{{-really_big}}."
    expected = {"key"=>"«Thïs ïs ä {{- really_big}}tést{{- really_big}}.»"}
    assert_equal(expected, @data.pseudoize_string)
  end

  def test_many_adjacent_i18next_vars
    @data['key'] = "purple{{one}}red{{two}}blue{{three}}green{{four}}yellow"
    expected = {"key"=>"«püřplé{{one}}řéd{{two}}blüé{{three}}gřééñ{{four}}yéllöω»"}
    assert_equal(expected, @data.pseudoize_string)
  end

  def test_many_adjacent_i18next_vars_w_html_escape
    @data['key'] = "purple{{-one}}red{{-   <h1>two</h1>}}blue{{- three}}green{{- four}}yellow"
    expected = {"key"=>"«püřplé{{- one}}řéd{{- <h1>two</h1>}}blüé{{- three}}gřééñ{{- four}}yéllöω»"}
    assert_equal(expected, @data.pseudoize_string)
  end

  def test_adjacent_i18next_vars_with_real_example
    @data['key'] = "Used in conjunction with the Cuts entity to track editorial-related " \
                   "information. For more information about Shotgun’s editorial schema, click " \
                   "{{-markup_start}}here{{- markup_end}}."
    expected = {"key"=>"«Üséd ïñ çöñjüñçtïöñ ωïth thé Çüts éñtïty tö třäçk édïtöřïäl-řélätéd " \
                       "ïñföřmätïöñ. Föř möřé ïñföřmätïöñ äböüt Shötgüñ’s édïtöřïäl sçhémä, " \
                       "çlïçk {{- markup_start}}héřé{{- markup_end}}.»"}
    assert_equal(expected, @data.pseudoize_string)
  end

  def test_quote_special_entity_code_is_left_as_is
    @data['key'] = "You said &quot;How are you?&quot;"
    expected = {"key"=>"«Ýöü säïd &quot;Höω äřé yöü?&quot;»"}
    assert_equal(expected, @data.pseudoize_string)
  end

  def test_quote_special_entity_code_near_interpolation_is_left_as_is
    @data['key'] = "You said &quot;{{some_var_name}}&quot;"
    expected = {"key"=>"«Ýöü säïd &quot;{{some_var_name}}&quot;»"}
    assert_equal(expected, @data.pseudoize_string)
  end

  def test_interpolation_values_with_slashes
    date_format = 'd/m'
    @data['key'] = "Invalid date format: valid formats include 'may 3', 'tomorrow', '2008-m-d', '{{#{date_format}}}/07' or '{{#{date_format}}}'"
    expected = {"key"=>"«Iñvälïd däté föřmät: välïd föřmäts ïñçlüdé 'mäy 3', 'tömöřřöω', '2008-m-d', '{{d/m}}/07' öř '{{d/m}}'»"}
    assert_equal(expected, @data.pseudoize_string)

    date_format = 'm/d'
    @data['key'] = "Invalid date format: valid formats include 'may 3', 'tomorrow', '2008-m-d', '{{#{date_format}}}/07' or '{{#{date_format}}}'"
    expected = {"key"=>"«Iñvälïd däté föřmät: välïd föřmäts ïñçlüdé 'mäy 3', 'tömöřřöω', '2008-m-d', '{{m/d}}/07' öř '{{m/d}}'»"}
    assert_equal(expected, @data.pseudoize_string)
  end
end
