{{ config(materialized='table') }}

select
    parent_asin,
    product_title,

    sum(number_of_helpful_votes) as total_helpful_votes,
    avg(number_of_helpful_votes) as avg_helpful_votes,
    max(number_of_helpful_votes) as max_helpful_votes

from {{ ref('int_joined_product_data') }}
group by parent_asin, product_title
