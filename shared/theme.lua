Config.Theme = {
    -- The menu uses "heritage" when the server's UI theme is heritage (replicated convar hrp_ui_theme, read in
    -- game/nui.lua), this theme otherwise
    currentTheme = "qb-core",
    themes = {
        {
            -- Green terminal look, with the heritage-theme rules of web/dist/index.html
            id = "heritage",
            borderRadius = "0px",
            fontColor = "26, 255, 128",
            fontColorHover = "26, 255, 128",
            fontColorSelected = "5, 15, 8",
            fontFamily = "Share Tech Mono",
            primaryBackground = "5, 15, 8",
            primaryBackgroundSelected = "26, 255, 128",
            secondaryBackground = "10, 30, 15",
            scaleOnHover = false,
            sectionFontWeight = "normal",
            smoothBackgroundTransition = false
        },
        {
            id = "default",
            borderRadius = "4px",
            fontColor = "255, 255, 255",
            fontColorHover = "255, 255, 255",
            fontColorSelected = "0, 0, 0",
            fontFamily = "Inter",
            primaryBackground = "0, 0, 0",
            primaryBackgroundSelected = "255, 255, 255",
            secondaryBackground = "0, 0, 0",
            scaleOnHover = false,
            sectionFontWeight = "normal",
            smoothBackgroundTransition = false
        },
        {
            id = "qb-core",
            borderRadius = "3vh",
            fontColor = "255, 255, 255",
            fontColorHover = "255, 255, 255",
            fontColorSelected = "255, 255, 255",
            fontFamily = "Poppins",
            primaryBackground = "220, 20, 60",
            primaryBackgroundSelected = "220, 20, 60",
            secondaryBackground = "23, 23, 23",
            scaleOnHover = true,
            sectionFontWeight = "bold",
            smoothBackgroundTransition = true
        },
        {
            id = "project-sloth",
            borderRadius = "6vh",
            fontColor = "255, 255, 255",
            fontColorHover = "255, 255, 255",
            fontColorSelected = "255, 255, 255",
            fontFamily = "Inter",
            primaryBackground = "2, 241, 181",
            primaryBackgroundSelected = "2, 241, 181",
            secondaryBackground = "27, 24, 69",
            scaleOnHover = true,
            sectionFontWeight = "bold",
            smoothBackgroundTransition = false
        },
        {
            id = "not-heavily-inspired",
            borderRadius = "10vh",
            fontColor = "255, 255, 255",
            fontColorHover = "255, 255, 255",
            fontColorSelected = "255, 255, 255",
            fontFamily = "Inter",
            primaryBackground = "149, 239, 119",
            primaryBackgroundSelected = "242, 163, 101",
            secondaryBackground = "25, 46, 70",
            scaleOnHover = true,
            sectionFontWeight = "bold",
            smoothBackgroundTransition = false
        }
    }
}
