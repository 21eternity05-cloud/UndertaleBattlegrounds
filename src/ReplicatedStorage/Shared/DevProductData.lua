local DevProductData = {
	Sections = {
		{
			Id = "Support",
			DisplayName = "Support / Donate",
			Order = 1,
			OpenByDefault = true,
			Enabled = true,
			Products = {
				"Support25",
			},
		},
		{
			Id = "DustBundles",
			DisplayName = "Dust Bundles",
			Order = 2,
			Enabled = false,
			ComingSoonText = "Coming soon",
			Products = {},
		},
		{
			Id = "Gamepasses",
			DisplayName = "Gamepasses",
			Order = 3,
			Enabled = false,
			ComingSoonText = "Coming soon",
			Products = {},
		},
	},

	Products = {
		Support25 = {
			DisplayName = "Support the Game",
			Description = "Optional donation. Gives no gameplay advantage.",
			ProductType = "Donation",
			AmountRobux = 25,
			ProductId = 3604673564,
			Order = 1,
		},
	},
}

function DevProductData.GetProductByProductId(productId)
	local numericProductId = tonumber(productId)
	if not numericProductId or numericProductId <= 0 then
		return nil, nil
	end

	for productKey, product in pairs(DevProductData.Products) do
		if typeof(product) == "table" and product.ProductId == numericProductId then
			return productKey, product
		end
	end

	return nil, nil
end

return DevProductData
