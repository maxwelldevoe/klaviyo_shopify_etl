import requests
import time
import json
import base64

def sync_shopify_data_to_klaviyo():
    """
    Function to sync historical order data from Shopify to Klaviyo
    1. Fetch order data from Shopify
    2. Serialize order data to Klaviyo's recommended event format
    3. Track data using Klaviyo track API
    """
    order_data = _get_order_data_from_shopify(API_KEY, PASSWORD, SHOP_NAME)
    serialized_orders, serialized_products = _serialize_order_and_product_data(order_data["orders"])
    tracked_events = _track_events(serialized_orders, serialized_products)
    print(tracked_events)




def _get_order_data_from_shopify(api_key:str, password:str, shop_name:str):
    """
    This function uses the request library to fetch order data from the shopify API.
    1. Use string interpolation to build the request URL using values from the required function params.
    2. Convert response to json format.
    """

    response = requests.get(f"https://{api_key}:{password}@{shop_name}.myshopify.com/admin/orders.json?created_at_min=2016-01-01&created_at_max=2016-12-31")

    return response.json()


def _serialize_order_and_product_data(order_data:dict):
    """
    This function takes the shopify order data and serializes it to Klaviyo's recommended event json format.
    1. Define event lists.
    2. Iterate over order data and serialize.
    """

    placed_orders = []
    ordered_products = []

    for order in order_data:
        if order["financial_status"] not in COMPLETE_ORDER_STATUSES:
            continue
        
        items = []
        products = []
        for item in order["line_items"]:
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
                    "$address1": order["customer"]["default_address"]["address1"] if "default_address" in order["customer"].keys() else None,
                    "$address2": order["customer"]["default_address"]["address2"] if "default_address" in order["customer"].keys() else None,
                    "$city": order["customer"]["default_address"]["city"] if "default_address" in order["customer"].keys() else None,
                    "$zip": order["customer"]["default_address"]["zip"] if "default_address" in order["customer"].keys() else None,
                    "$region": order["customer"]["default_address"]["province_code"] if "default_address" in order["customer"].keys() else None,
                    "$country": order["customer"]["default_address"]["country_name"] if "default_address" in order["customer"].keys() else None,
                },
                "properties": {
                    "$event_id": order["id"],
                    "$value": order["total_price"],
                    "ItemNames": [item["name"] for item in order["line_items"]],
                    "DiscountCode": order["discount_codes"],
                    "DiscountValue": order["total_discounts"],
                    "Items": items,
                    "BillingAddress": None if "billing_address" not in order.keys() else
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
                    "ShippingAddress": None if "shipping_address" not in order.keys() else
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
                "time": int(time.time())
            }
        )
    
    return placed_orders, ordered_products


def _track_events(orders:list, products:list):
    """
    This Function makes requests to the Klaviyo track API.
    1. Link products to order
    2. Encode product JSON dictionaries
    3. Make requests
    """

    order_and_product_responses = []

    for order in orders:

        product_responses = []
        for product in products:
            if product["order_id"] == order['properties']['$event_id']:
                for item in product["body"]:
                    product_responses.append(
                        {
                            "id": item["properties"]["$event_id"],
                            "klaviyo_track_product_response": requests.get(f"https://a.klaviyo.com/api/track?data={__encode_json_dictionary(item)}").json()
                        }
                    )
        
        order_and_product_responses.append(
            {
                "order": order["properties"]["$event_id"],
                "klaviyo_track_order_response": requests.get(f"https://a.klaviyo.com/api/track?data={__encode_json_dictionary(order)}").json(),
                "products": product_responses
            }
        )

    return order_and_product_responses
                



def __encode_json_dictionary(json_dict:dict):
    """
    This function converts a JSON dictionary to a base64 encoded JSON string
    1. Convert dict into JSON string
    2. Covnert string to bytes
    3. Encode JSON string using base64
    """

    json_string = json.dumps(json_dict)

    return base64.b64encode(json_string.encode()).decode()



    


if __name__ == "__main__":
    sync_shopify_data_to_klaviyo()