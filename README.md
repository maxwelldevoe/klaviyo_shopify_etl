# Shopify ETL Script

## This script fetches all complete 2016 order data and imports it into Klaviyo.

### Steps:
1. Fetch shopify order data using the order api url string.
2. Serialize data into approved Klaviyo JSON format.
    - This involves separating data into placed orders and ordered products, then grouping them together by order id.
3. Track events by order.
    - This takes the order and product arrays and links them together by the order id they were already grouped by, then makes the request to Klaviyo's track API.

---

## Response Object JSON:

### The response object from this script is an array of placed orders, their products, and the Klaviyo track API request response value.

```
[
  {
    'order': 2864645316,
    'klaviyo_track_response': 1,
    'products': [
      {
        'id': 5468961156,
        'klaviyo_track_product_response': 1
      }
    ]
  },
  {
    'order': 2864509828,
    'klaviyo_track_response': 1,
    'products': [
      {
        'id': 5468684228,
        'klaviyo_track_product_response': 1
      }
    ]
  }
]
```

---

## Run Locally:
1. Clone Repository
2. CD into top level directory
3. Run: `python shopify_klaviyo.py`