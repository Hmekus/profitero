# frozen_string_literal: true

require "curb"
require "nokogiri"
require "csv"

class DoggyParser
  HEADERS_ROW = %w(Name Price Image).freeze

  def initialize(category_url, file_name)
    @category_url = category_url
    @file_name = file_name
  end

  def call
    return puts("No url or file name provided") if [category_url, file_name].any?(&:nil?)

    csv = ::CSV.open(file_name, "w")
    csv << HEADERS_ROW

    parsed_pages_count = 0
    (1..total_pages_count).each do |page_number|
      category_page_body = page_body(url: "#{category_url}?p=#{page_number}")
      product_url_nodes = parse_body(body: category_page_body, xpath: "//a[@class='product-name']")

      product_url_nodes.each do |node|
        product_url = node.attributes.fetch("href").value
        puts "Parsing #{product_url}"

        product_page_body = page_body(url: product_url)

        product_name = parse_body(body: product_page_body, xpath: "//h1[@class='product_main_name']").first.content

        parse_body(body: product_page_body, xpath: "//ul[@class='attribute_radio_list']/li/label").each do |item_node|
          product_weight = item_node.children.at("span[@class='radio_label']").content
          product_name_and_weight = "#{product_name} - #{product_weight}"

          product_price = item_node.children.at("span[@class='price_comb']").content

          product_image_url = parse_body(body: product_page_body, xpath: "//div[@id='image-block']/span/img").first.attributes.fetch("src").value

          csv << [product_name_and_weight, product_price, product_image_url]

          sleep(rand(1.0..2.0))
        end

        parsed_pages_count += 1
      end
    end

    csv.close
    puts "Parsing complete! Parsed pages count: #{parsed_pages_count}"
  rescue => e
    csv.close
    puts "Something went wrong... Parsed pages count: #{parsed_pages_count}. Exception: #{e}"
  end

  private

  attr_reader :category_url, :file_name

  def total_pages_count
    category_page_body = page_body(url: category_url)
    product_quantity_node = parse_body(body: category_page_body, xpath: "//input[@id='nb_item_bottom']")
    return 1 if product_quantity_node.empty?

    total_products_count = product_quantity_node.attribute("value").value.to_i
    products_per_page_count = parse_body(body: category_page_body, xpath: "//a[@class='product-name']").count
    (total_products_count.to_f / products_per_page_count.to_f).ceil
  end

  def page_body(url:)
    easy = Curl::Easy.new
    easy.follow_location = true
    easy.max_redirects = 3
    easy.url = url
    easy.perform
    easy.body_str
  end

  def parse_body(body:, xpath:)
    Nokogiri::HTML(body).xpath(xpath)
  end
end

url = ARGV[0]
file_name = ARGV[1]
DoggyParser.new(url, file_name).call
