{{ config(materialized='table') }}

select
    parent_asin,
    product_title,
    count(review_message) as number_of_reviews,
    avg(user_rating) as avg_rating,
    sum(number_of_helpful_votes) as total_helpful_votes,
    max(price) as current_price
from {{ ref('int_joined_product_data') }}
group by product_title, parent_asin
order by number_of_reviews
