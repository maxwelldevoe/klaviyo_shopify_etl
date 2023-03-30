require 'uri'
require 'net/http'
require 'json'
require 'base64'

=begin
    This script is the ruby equivalent of the python script.
=end

def sync_shopify_data_to_klaviyo()
=begin
    Function to sync historical order data from Shopify to Klaviyo
    1. Fetch order data from Shopify
    2. Serialize order data to Klaviyo's recommended event format
    3. Track data using Klaviyo track API
=end
    order_data = get_order_data_from_shopify(API_KEY, PASSWORD, SHOP_NAME)
    serialized_orders, serialized_products = serialize_order_and_product_data(order_data["orders"])
    tracked_events = track_events(serialized_orders, serialized_products)
    puts tracked_events
end

def get_order_data_from_shopify(api_key, password, shop_name)
=begin
    This function uses the request library to fetch order data from the shopify API.
    1. Use string interpolation to build the request URL using values from the required function params.
    2. Convert response to json format.
=end
    url = URI("https://#{api_key}:#{password}@#{shop_name}.myshopify.com/admin/orders.json?created_at_min=2016-01-01&created_at_max=2016-12-31")
    https = Net::HTTP.new(url.host, url.port)
    https.use_ssl = true
    request = Net::HTTP::Get(url)
    response = https.request(request)
    JSON.parse(response.read_body)
end

def serialize_order_and_product_data(order_data)
=begin
    This function takes the shopify order data and serializes it to Klaviyo's recommended event json format.
    1. Define event lists.
    2. Iterate over order data and serialize.
=end
    placed_orders = []
    ordered_products = []

    order_data.each do |order|
        next unless COMPLETE_ORDER_STATUSES.include?(order["financial_status"])
        
        items = []
        products = []
        order["line_items"].each do |item|
            items.append(
                {
                    "ProductID": item["id"],
                    "SKU": item["sku"],
                    "ProductName": item["title"],
                    "Quantity": item["quantity"],
                    "ItemPrice": item["name"]
                }
            )
    
            products.append(
                {
                    "token": PUBLIC_KEY,
                    "event": "Ordered Product",
                    "customer_properties": {
                        "$email": order["customer"]["email"],
                        "$first_name": order["customer"]["first_name"],
                        "$last_name": order["customer"]["last_name"]
                    },
                    "properties": {
                        "$event_id": item["id"],
                        "$value": item["price"],
                        "ProductID": item["product_id"],
                        "SKU": item["sku"],
                        "ProductName": item["title"],
                        "Quantity": item["quantity"]
                    }
                }
            )
        end
        
        ordered_products.append({"order_id":order["id"], "body": products})
    
        placed_orders.append(
            {
                "token": PUBLIC_KEY,
                "event": "Placed Order",
                "customer_properties": {
                    "$email": order["customer"]["email"],
                    "$first_name": order["customer"]["first_name"],
                    "$last_name": order["customer"]["last_name"],
                    "$phone_number": order["customer"]["phone"],
                    "$address1": order["customer"]["default_address"]["address1"] ? order["customer"].key?("default_address") : nil,
                    "$address2": order["customer"]["default_address"]["address2"] ? order["customer"].key?("default_address") : nil,
                    "$city": order["customer"]["default_address"]["city"] ? order["customer"].key?("default_address") : nil,
                    "$zip": order["customer"]["default_address"]["zip"] ? order["customer"].key?("default_address") : nil,
                    "$region": order["customer"]["default_address"]["province_code"] ? order["customer"].key?("default_address") : nil,
                    "$country": order["customer"]["default_address"]["country_name"] ? order["customer"].key?("default_address") : nil,
                },
                "properties": {
                    "$event_id": order["id"],
                    "$value": order["total_price"],
                    "ItemNames": order["line_items"].map { |item| item["name"] },
                    "DiscountCode": order["discount_codes"],
                    "DiscountValue": order["total_discounts"],
                    "Items": items,
                    "BillingAddress": nil ? !order.key?("billing_address") :
                        {
                            "FirstName": order["billing_address"]["first_name"],
                            "LastName": order["billing_address"]["last_name"],
                            "Company": order["billing_address"]["company"],
                            "Addaress1": order["billing_address"]["address1"],
                            "Address2": order["billing_address"]["address2"],
                            "City": order["billing_address"]["city"],
                            "Region": order["billing_address"]["province"],
                            "RegionCode": order["billing_address"]["province_code"],
                            "Country": order["billing_address"]["country"],
                            "CountryCode": order["billing_address"]["country_code"],
                            "Zip": order["billing_address"]["zip"],
                            "Phone": order["billing_address"]["phone"]
                        },
                        "ShippingAddress": nil ? !order.key?("shipping_address") :
                            {
                            "FirstName": order["shipping_address"]["first_name"],
                            "LastName": order["shipping_address"]["last_name"],
                            "Company": order["shipping_address"]["company"],
                            "Addaress1": order["shipping_address"]["address1"],
                            "Address2": order["shipping_address"]["address2"],
                            "City": order["shipping_address"]["city"],
                            "Region": order["shipping_address"]["province"],
                            "RegionCode": order["shipping_address"]["province_code"],
                            "Country": order["shipping_address"]["country"],
                            "CountryCode": order["shipping_address"]["country_code"],
                            "Zip": order["shipping_address"]["zip"],
                            "Phone": order["shipping_address"]["phone"]
                            }
                },
                "time": Time.now.to_i
            }
        )
    end
    return placed_orders, ordered_products
end
  
def _track_events(orders, products)
    order_and_product_responses = []

    orders.each do |order|
        product_responses = []

        products.each do |product|
        if product["order_id"] == order['properties']['$event_id']
            product["body"].each do |item|
            product_responses << {
                "id" => item["properties"]["$event_id"],
                "klaviyo_track_product_response" => JSON.parse(
                    Net::HTTP.get(
                        URI.parse("https://a.klaviyo.com/api/track?data=#{__encode_json_dictionary(item)}")
                    )
                )
            }
            end
        end
    end

        order_and_product_responses << {
            "order" => order["properties"]["$event_id"],
            "klaviyo_track_order_response" => JSON.parse(
                Net::HTTP.get(
                    URI.parse("https://a.klaviyo.com/api/track?data=#{__encode_json_dictionary(order)}")
                )
            ),
            "products" => product_responses
        }
    end

    order_and_product_responses
end

def encode_json_dictionary(json_hash)
=begin
    This function converts a JSON dictionary to a base64 encoded JSON string
    1. Convert dict into JSON string
    2. Covnert string to bytes
    3. Encode JSON string using base64
=end
  
    json_string = json_hash.to_json
  
    return Base64.strict_encode64(json_string.encode('utf-8'))
end