return {
  { -- Add indentation guides even on blank lines
    'lukas-reineke/indent-blankline.nvim',
    -- Enable `lukas-reineke/indent-blankline.nvim`
    -- See `:help ibl`
    main = 'ibl',
    ops = {
       config = {
	  indent = {
	     char = '┊',
	  },
       },
       show_trailing_blankline_indent = false,
    },
  },
}
