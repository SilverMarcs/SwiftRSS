//
//  StarterFeeds.swift
//  SwiftRSS
//
//  Created by Zabir Raihan on 02/04/2026.
//

import Foundation

struct StarterFeed: Identifiable {
    let name: String
    let url: String
    let category: String

    var id: String { url }

    var iconURL: URL? {
        guard let feedURL = URL(string: url),
              let host = feedURL.host else { return nil }
        return URL(string: "https://www.google.com/s2/favicons?domain=\(host)&sz=64")
    }
}

enum StarterFeedCategory: String, CaseIterable {
    case tech = "Tech"
    case apple = "Apple"
    case dev = "Development"
    case news = "News"
    case design = "Design"
    case science = "Science"
    case gaming = "Gaming"
    case finance = "Finance"
    case entertainment = "Entertainment"
    case sports = "Sports"
    case food = "Food & Cooking"
    case security = "Security"
    case ai = "AI & Machine Learning"
    case linux = "Linux & Open Source"
    case photography = "Photography"
    case productivity = "Productivity"

    var icon: String {
        switch self {
        case .tech: "cpu"
        case .apple: "apple.logo"
        case .dev: "chevron.left.forwardslash.chevron.right"
        case .news: "newspaper"
        case .design: "paintbrush"
        case .science: "atom"
        case .gaming: "gamecontroller"
        case .finance: "chart.line.uptrend.xyaxis"
        case .entertainment: "film"
        case .sports: "sportscourt"
        case .food: "fork.knife"
        case .security: "lock.shield"
        case .ai: "brain"
        case .linux: "terminal"
        case .photography: "camera"
        case .productivity: "checkmark.circle"
        }
    }

    var feeds: [StarterFeed] {
        Self.allFeeds.filter { $0.category == rawValue }
    }

    static let allFeeds: [StarterFeed] = [
        // MARK: - Tech
        StarterFeed(name: "The Verge", url: "https://www.theverge.com/rss/index.xml", category: "Tech"),
        StarterFeed(name: "Ars Technica", url: "https://feeds.arstechnica.com/arstechnica/index", category: "Tech"),
        StarterFeed(name: "Hacker News", url: "https://news.ycombinator.com/rss", category: "Tech"),
        StarterFeed(name: "TechCrunch", url: "https://techcrunch.com/feed/", category: "Tech"),
        StarterFeed(name: "Wired", url: "https://www.wired.com/feed/rss", category: "Tech"),
        StarterFeed(name: "Engadget", url: "https://www.engadget.com/rss.xml", category: "Tech"),
        StarterFeed(name: "MIT Technology Review", url: "https://www.technologyreview.com/feed/", category: "Tech"),
        StarterFeed(name: "Lifehacker", url: "https://lifehacker.com/feed/rss", category: "Tech"),
        StarterFeed(name: "Gizmodo", url: "https://gizmodo.com/feed", category: "Tech"),
        StarterFeed(name: "How-To Geek", url: "https://www.howtogeek.com/feed/", category: "Tech"),

        // MARK: - Apple
        StarterFeed(name: "9to5Mac", url: "https://9to5mac.com/feed/", category: "Apple"),
        StarterFeed(name: "Daring Fireball", url: "https://daringfireball.net/feeds/main", category: "Apple"),
        StarterFeed(name: "MacRumors", url: "https://feeds.macrumors.com/MacRumors-All", category: "Apple"),
        StarterFeed(name: "Six Colors", url: "https://sixcolors.com/feed/", category: "Apple"),
        StarterFeed(name: "MacStories", url: "https://www.macstories.net/feed/", category: "Apple"),
        StarterFeed(name: "AppleInsider", url: "https://appleinsider.com/rss/news/", category: "Apple"),
        StarterFeed(name: "Cult of Mac", url: "https://www.cultofmac.com/feed/", category: "Apple"),
        StarterFeed(name: "iMore", url: "https://www.imore.com/feed", category: "Apple"),
        StarterFeed(name: "512 Pixels", url: "https://512pixels.net/feed/", category: "Apple"),
        StarterFeed(name: "The Loop", url: "https://www.loopinsight.com/feed/", category: "Apple"),

        // MARK: - Development
        StarterFeed(name: "Swift by Sundell", url: "https://swiftbysundell.com/rss", category: "Development"),
        StarterFeed(name: "Hacking with Swift", url: "https://www.hackingwithswift.com/articles/rss", category: "Development"),
        StarterFeed(name: "NSHipster", url: "https://nshipster.com/feed.xml", category: "Development"),
        StarterFeed(name: "CSS-Tricks", url: "https://css-tricks.com/feed/", category: "Development"),
        StarterFeed(name: "Swift with Majid", url: "https://swiftwithmajid.com/feed.xml", category: "Development"),
        StarterFeed(name: "Donny Wals", url: "https://www.donnywals.com/feed/", category: "Development"),
        StarterFeed(name: "SwiftLee", url: "https://www.avanderlee.com/feed/", category: "Development"),
        StarterFeed(name: "Kodeco", url: "https://www.kodeco.com/feed.xml", category: "Development"),
        StarterFeed(name: "Dev.to", url: "https://dev.to/feed", category: "Development"),
        StarterFeed(name: "Smashing Magazine", url: "https://www.smashingmagazine.com/feed/", category: "Development"),
        StarterFeed(name: "Martin Fowler", url: "https://martinfowler.com/feed.atom", category: "Development"),
        StarterFeed(name: "Joel on Software", url: "https://www.joelonsoftware.com/feed/", category: "Development"),

        // MARK: - News
        StarterFeed(name: "BBC News", url: "https://feeds.bbci.co.uk/news/rss.xml", category: "News"),
        StarterFeed(name: "NPR News", url: "https://feeds.npr.org/1001/rss.xml", category: "News"),
        StarterFeed(name: "The Guardian", url: "https://www.theguardian.com/world/rss", category: "News"),
        StarterFeed(name: "Al Jazeera", url: "https://www.aljazeera.com/xml/rss/all.xml", category: "News"),
        StarterFeed(name: "The Economist", url: "https://www.economist.com/international/rss.xml", category: "News"),
        StarterFeed(name: "ABC News", url: "https://abcnews.go.com/abcnews/topstories", category: "News"),

        // MARK: - Design
        StarterFeed(name: "Dribbble Blog", url: "https://dribbble.com/stories.rss", category: "Design"),
        StarterFeed(name: "UX Collective", url: "https://uxdesign.cc/feed", category: "Design"),
        StarterFeed(name: "Creative Bloq", url: "https://www.creativebloq.com/feeds.xml", category: "Design"),
        StarterFeed(name: "Webdesigner Depot", url: "https://www.webdesignerdepot.com/feed/", category: "Design"),
        StarterFeed(name: "Codrops", url: "https://tympanus.net/codrops/feed/", category: "Design"),

        // MARK: - Science
        StarterFeed(name: "Nature", url: "https://www.nature.com/nature.rss", category: "Science"),
        StarterFeed(name: "NASA Breaking News", url: "https://www.nasa.gov/news-release/feed/", category: "Science"),
        StarterFeed(name: "Science Daily", url: "https://www.sciencedaily.com/rss/all.xml", category: "Science"),
        StarterFeed(name: "New Scientist", url: "https://www.newscientist.com/feed/home/", category: "Science"),
        StarterFeed(name: "Quanta Magazine", url: "https://quantamagazine.org/feed/", category: "Science"),
        StarterFeed(name: "Phys.org", url: "https://phys.org/rss-feed/", category: "Science"),
        StarterFeed(name: "Space.com", url: "https://www.space.com/feeds/all", category: "Science"),

        // MARK: - Gaming
        StarterFeed(name: "Kotaku", url: "https://kotaku.com/rss", category: "Gaming"),
        StarterFeed(name: "IGN", url: "https://feeds.feedburner.com/ign/all", category: "Gaming"),
        StarterFeed(name: "Polygon", url: "https://www.polygon.com/rss/index.xml", category: "Gaming"),
        StarterFeed(name: "PC Gamer", url: "https://www.pcgamer.com/rss/", category: "Gaming"),
        StarterFeed(name: "Eurogamer", url: "https://www.eurogamer.net/feed", category: "Gaming"),
        StarterFeed(name: "Rock Paper Shotgun", url: "https://www.rockpapershotgun.com/feed", category: "Gaming"),
        StarterFeed(name: "TouchArcade", url: "https://toucharcade.com/feed/", category: "Gaming"),
        StarterFeed(name: "Nintendo Life", url: "https://www.nintendolife.com/feeds/latest", category: "Gaming"),

        // MARK: - Finance
        StarterFeed(name: "Bloomberg", url: "https://feeds.bloomberg.com/markets/news.rss", category: "Finance"),
        StarterFeed(name: "Financial Times", url: "https://www.ft.com/rss/home", category: "Finance"),
        StarterFeed(name: "MarketWatch", url: "https://feeds.content.dowjones.io/public/rss/mw_topstories", category: "Finance"),
        StarterFeed(name: "Planet Money (NPR)", url: "https://feeds.npr.org/510289/podcast.xml", category: "Finance"),

        // MARK: - Entertainment
        StarterFeed(name: "Variety", url: "https://variety.com/feed/", category: "Entertainment"),
        StarterFeed(name: "The Hollywood Reporter", url: "https://www.hollywoodreporter.com/feed/", category: "Entertainment"),
        StarterFeed(name: "Deadline", url: "https://deadline.com/feed/", category: "Entertainment"),
        StarterFeed(name: "Rolling Stone", url: "https://www.rollingstone.com/feed/", category: "Entertainment"),
        StarterFeed(name: "Pitchfork", url: "https://www.pitchfork.com/feed/feed-news/rss", category: "Entertainment"),
        StarterFeed(name: "IndieWire", url: "https://www.indiewire.com/feed/", category: "Entertainment"),

        // MARK: - Sports
        StarterFeed(name: "ESPN", url: "https://www.espn.com/espn/rss/news", category: "Sports"),
        StarterFeed(name: "BBC Sport", url: "https://feeds.bbci.co.uk/sport/rss.xml", category: "Sports"),
        StarterFeed(name: "SB Nation", url: "https://www.sbnation.com/rss/index.xml", category: "Sports"),

        // MARK: - Food & Cooking
        StarterFeed(name: "Smitten Kitchen", url: "https://smittenkitchen.com/feed/", category: "Food & Cooking"),
        StarterFeed(name: "Budget Bytes", url: "https://www.budgetbytes.com/feed/", category: "Food & Cooking"),
        StarterFeed(name: "Bon Appétit", url: "https://www.bonappetit.com/feed/rss", category: "Food & Cooking"),

        // MARK: - Security
        StarterFeed(name: "Krebs on Security", url: "https://krebsonsecurity.com/feed/", category: "Security"),
        StarterFeed(name: "Schneier on Security", url: "https://www.schneier.com/feed/atom/", category: "Security"),
        StarterFeed(name: "The Hacker News", url: "https://feeds.feedburner.com/TheHackersNews", category: "Security"),
        StarterFeed(name: "Dark Reading", url: "https://www.darkreading.com/rss.xml", category: "Security"),
        StarterFeed(name: "Troy Hunt", url: "https://www.troyhunt.com/rss/", category: "Security"),

        // MARK: - AI & Machine Learning
        StarterFeed(name: "OpenAI Blog", url: "https://openai.com/news/rss.xml", category: "AI & Machine Learning"),
        StarterFeed(name: "Google AI Blog", url: "https://blog.google/technology/ai/rss/", category: "AI & Machine Learning"),
        StarterFeed(name: "Towards Data Science", url: "https://towardsdatascience.com/feed", category: "AI & Machine Learning"),
        StarterFeed(name: "Machine Learning Mastery", url: "https://machinelearningmastery.com/feed/", category: "AI & Machine Learning"),
        StarterFeed(name: "Hugging Face Blog", url: "https://huggingface.co/blog/feed.xml", category: "AI & Machine Learning"),

        // MARK: - Linux & Open Source
        StarterFeed(name: "OMG! Ubuntu!", url: "https://www.omgubuntu.co.uk/feed", category: "Linux & Open Source"),
        StarterFeed(name: "Phoronix", url: "https://www.phoronix.com/rss.php", category: "Linux & Open Source"),
        StarterFeed(name: "Linux Journal", url: "https://www.linuxjournal.com/node/feed", category: "Linux & Open Source"),
        StarterFeed(name: "LWN.net", url: "https://lwn.net/headlines/rss", category: "Linux & Open Source"),
        StarterFeed(name: "Fedora Magazine", url: "https://fedoramagazine.org/feed/", category: "Linux & Open Source"),

        // MARK: - Photography
        StarterFeed(name: "PetaPixel", url: "https://petapixel.com/feed/", category: "Photography"),
        StarterFeed(name: "DPReview", url: "https://www.dpreview.com/feeds/news.xml", category: "Photography"),
        StarterFeed(name: "Fstoppers", url: "https://fstoppers.com/feed", category: "Photography"),
        StarterFeed(name: "DIY Photography", url: "https://feeds.feedburner.com/Diyphotographynet", category: "Photography"),
        StarterFeed(name: "500px Blog", url: "https://iso.500px.com/feed/", category: "Photography"),

        // MARK: - Productivity
        StarterFeed(name: "Zen Habits", url: "https://feeds.feedburner.com/zenhabits", category: "Productivity"),
        StarterFeed(name: "James Clear", url: "https://jamesclear.com/feed", category: "Productivity"),
        StarterFeed(name: "Cal Newport", url: "https://calnewport.com/feed/", category: "Productivity"),
        StarterFeed(name: "Asian Efficiency", url: "https://www.asianefficiency.com/feed/", category: "Productivity"),
        StarterFeed(name: "Farnam Street", url: "https://fs.blog/feed/", category: "Productivity"),
    ]
}
