{{ config(materialized='table') }}

with seller_metrics as (

    select
        seller,

        -- total reviews
        count(*) as total_reviews,

        -- reviews with no message
        sum(
            case
                when review_message is null
                     or trim(review_message) = ''
                then 1
                else 0
            end
        ) as reviews_without_message,

        -- 5-star reviews
        sum(
            case
                when user_rating = 5 then 1
                else 0
            end
        ) as five_star_reviews,

        -- 1-star reviews
        sum(
            case
                when user_rating = 1 then 1
                else 0
            end
        ) as one_star_reviews,

        -- average rating
        avg(user_rating) as avg_rating

    from {{ ref('int_joined_product_data') }}
    group by seller
)

select
    seller,
    total_reviews,
    reviews_without_message,
    five_star_reviews,
    one_star_reviews,
    avg_rating,

    -- percentages
    reviews_without_message * 1.0 / total_reviews as pct_reviews_without_message,
    five_star_reviews * 1.0 / total_reviews as pct_five_star_reviews,
    one_star_reviews * 1.0 / total_reviews as pct_one_star_reviews

from seller_metrics
order by total_reviews desc
