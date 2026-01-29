{{ config(materialized='table') }}

select
    parent_asin,

    count(*) as total_reviews,

    sum(
        case
            when review_message is null or trim(review_message) = ''
            then 1 else 0
        end
    ) as reviews_without_text,

    round(
        sum(
            case
                when review_message is null or trim(review_message) = ''
                then 1 else 0
            end
        ) * 100.0 / count(*),
        2
    ) as pct_reviews_without_text,

    avg(number_of_helpful_votes) as avg_helpful_votes

from {{ ref('int_joined_product_data') }}
group by parent_asin
