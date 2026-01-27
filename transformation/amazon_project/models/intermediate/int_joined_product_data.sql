{{ config(materialized='view') }}

with reviews as (

    select *
    from {{ ref('stg_reviews') }}

),

products as (

    select *
    from {{ ref('stg_meta') }}

)

select
    r.parent_asin,

    -- review fields
    r.helpful_vote as number_of_helpful_votes,
    r.rating as user_rating,
    r.text as review_message,

    -- product fields
    p.title as product_title,
    p.seller,
    p.price,
    p.average_rating,
    p.number_of_ratings

from reviews r
left join products p
  on r.parent_asin = p.parent_asin
