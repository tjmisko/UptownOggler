 #!/bin/bash 
dos2unix .env
source .env

fetch_prices() {
	curl -s "$APARTMENT_PRICE_API_URL"
}

filter_prices() {
	jq --argjson threshold $THRESHOLD '((.data.units | map({ floor_plan_id, price, area, display_unit_number, display_price, building , display_area, display_lease_term, available_on} + {oggled_at: (now | strflocaltime("%F %H:%M"))})) as $available_offers | .data.floor_plans | map(.id as $fpid | { id, filter_label, bedroom_count, bathroom_count, offers: $available_offers | map(select(.floor_plan_id == $fpid))} | select(.offers | length > 0) | select(.filter_label == ("A01", "A02", "A03", "A04", "A05", "A06", "S02", "S03", "S04", "S05", "S06")) | (.offers | map(.price | values) | min ) as $min_price | . += { "best_offer": .offers | map(select(.price == $min_price))[0] } | { filter_label, bedroom_count, price: .best_offer.price, area: .best_offer.area, display_unit_number: .best_offer.display_unit_number, display_price: .best_offer.display_price, building: .best_offer.building, display_area: .best_offer.display_area, display_lease_term: .best_offer.display_lease_term, available_on: .best_offer.available_on, oggled_at: .best_offer.oggled_at }) | map(select(.price < $threshold ))) as $special_offers | $special_offers | (($special_offers | map("* Unit " + .filter_label + " (" + .display_area + ") available on " + .available_on + " for " + .display_price + " per month\n") ) as $offer_strings | [ "TheUptown has " + ($special_offers | length | tostring ) + " offer(s) of interest:\n" ] + $offer_strings ) | add '
}

offers() {
	fetch_prices | jq --argjson threshold 5000 -r '((.data.units | map({ floor_plan_id, price, area, display_unit_number, display_price, building , display_area, display_lease_term, available_on} + {oggled_at: (now | strflocaltime("%F %H:%M"))})) as $available_offers | .data.floor_plans | map(.id as $fpid | { id, filter_label, bedroom_count, bathroom_count, offers: $available_offers | map(select(.floor_plan_id == $fpid))} | select(.offers | length > 0) | select(.filter_label == ("A01", "A02", "A03", "A04", "A05", "A06", "S02", "S03", "S04", "S05", "S06")) | (.offers | map(.price | values) | min ) as $min_price | . += { "best_offer": .offers | map(select(.price == $min_price))[0] } | { filter_label, bedroom_count, price: .best_offer.price, area: .best_offer.area, display_unit_number: .best_offer.display_unit_number, display_price: .best_offer.display_price, building: .best_offer.building, display_area: .best_offer.display_area, display_lease_term: .best_offer.display_lease_term, available_on: .best_offer.available_on, oggled_at: .best_offer.oggled_at }) | map(select(.price < $threshold ))) as $special_offers | $special_offers | (($special_offers | map("* Unit " + .filter_label + " (" + .display_area + ") available on " + .available_on + " for " + .display_price + " per month\n") ) as $offer_strings | [ "TheUptown has " + ($special_offers | length | tostring ) + " offer(s) of interest:\n" ] + $offer_strings ) | add '
}

push_notification_tristan() {
	HEADER="Content-Type: application/json"
	DATA='{"token": "$PUSHOVER_API_TOKEN", "user": "$PUSHOVER_USER_TOKEN_TRISTAN", "message": '$1'}'
	echo "$DATA"
	curl -X POST -H "$HEADER" -d "$DATA" https://api.pushover.net/1/messages.json
}

push_notification_jen() {
	HEADERS="Content-Type: application/json"
	DATA='{"token": "$PUSHOVER_API_TOKEN", "user": "$PUSHOVER_USER_TOKEN_JEN", "message": '$1'}'
	echo "$DATA"
	curl -X POST -H "$HEADER" -d "$DATA" https://api.pushover.net/1/messages.json
} 

uptown_oggle() {
	# Fetch prices, then push the notification if there's anything good in it
	MESSAGE=$(fetch_prices | filter_prices)
	if [[ $MESSAGE != *"TheUptown has 0 offer(s) of interest:"* ]]; then
		echo "$MESSAGE"
		push_notification_tristan "$MESSAGE"
		push_notification_jen "$MESSAGE"
	else
		echo "No offers of interest"
	fi
}
