// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/utils/Base64.sol";
import "@openzeppelin/contracts/utils/Strings.sol";

/// @title Agent Passport — daily check-in with soulbound badges
/// @notice A community collectible for Agent ID holders. Free to use:
///         check-in costs gas only, there is no mint fee, no token,
///         no promised return and no monetary value.
///         Only addresses holding an Agent ID (SPACE ID, ERC-721,
///         0x60b9262456de011f7d15a54cdd8c48baaa8b022f on BNB Chain)
///         can check in. Badges are soulbound (non-transferable). Each user
///         picks one of 5 art styles on their first check-in (0 black-gold
///         holo, 1 cyberpunk, 2 anime, 3 pixel, 4 fantasy); the style is
///         stored on-chain as a trait. Referral rewards are badges only,
///         never money: a referrer earns a badge at 1 / 3 / 10 successful
///         referrals, counted only when the referred address (a different
///         Agent ID holder) makes its first check-in, and the referrer
///         claims the badge in their own transaction (gas only).
///         There are no admin functions: no owner, no pause, no fee,
///         no minting by anyone except the check-in milestones below,
///         and the contract never holds funds (no payable functions).
interface IAgentID {
    function balanceOf(address owner) external view returns (uint256);
}

contract AgentPassport is ERC721, ERC721URIStorage {
    using Strings for uint256;

    IAgentID public constant AGENT_ID =
        IAgentID(0x60B9262456dE011F7d15a54CdD8c48bAaa8B022F);

    uint256 public constant GENESIS_CAP = 100;
    uint256 public constant STREAK_7 = 7;
    uint256 public constant STREAK_30 = 30;

    // Badge types: 0 = Genesis, 1 = 7-day streak, 2 = 30-day streak,
    // 3 = 1 referral, 4 = 3 referrals, 5 = 10 referrals
    uint256 public constant BADGE_GENESIS = 0;
    uint256 public constant BADGE_STREAK_7 = 1;
    uint256 public constant BADGE_STREAK_30 = 2;
    uint256 public constant BADGE_REF_1 = 3;
    uint256 public constant BADGE_REF_3 = 4;
    uint256 public constant BADGE_REF_10 = 5;

    string[5] public styles = [
        "Black-Gold Holo",
        "Cyberpunk",
        "Anime",
        "Pixel",
        "Fantasy"
    ];

    uint256 private _nextTokenId = 1;
    uint256 public totalCheckIns;

    string[12] public destinations = [
        "Neonia",
        "Kepler-442b",
        "Titan",
        "Proxima Centauri",
        "Trappist-1e",
        "Gliese 667C",
        "Andromeda IX",
        "Nebula Sector",
        "Stellar Port",
        "Orbit Station 09",
        "Cosmic Gate",
        "Sol System"
    ];

    struct UserInfo {
        uint256 streak;
        uint256 total;
        uint256 lastDay;
        bool hasGenesis;
        bool hasStreak7;
        bool hasStreak30;
        uint8 style;
        bool styleSet;
        address referredBy;
        uint256 invites;
        bool hasRef1;
        bool hasRef3;
        bool hasRef10;
    }

    mapping(address => UserInfo) public users;

    event CheckedIn(
        address indexed user,
        uint256 indexed day,
        uint256 streak,
        uint256 total,
        uint256 destination
    );
    event Referred(address indexed user, address indexed referrer);
    event BadgeMinted(
        address indexed user,
        uint256 indexed tokenId,
        uint256 indexed badgeType,
        uint256 streak
    );

    constructor() ERC721("Agent Passport", "AGPASS") {}

    function today() public view returns (uint256) {
        return block.timestamp / 1 days;
    }

    function destinationOf(address user, uint256 day) public view returns (uint256) {
        return uint256(keccak256(abi.encodePacked(user, day))) % destinations.length;
    }

    function canCheckIn(address user) public view returns (bool) {
        return users[user].lastDay < today();
    }

    function getUser(address user) public view returns (UserInfo memory) {
        return users[user];
    }

    function checkIn(address referrer, uint8 style) external {
        require(AGENT_ID.balanceOf(msg.sender) > 0, "Agent ID required");
        require(style < 5, "Invalid style");
        uint256 day = today();
        UserInfo storage u = users[msg.sender];
        require(u.lastDay < day, "Already checked in today");

        bool firstCheckIn = (u.total == 0);
        if (firstCheckIn) {
            u.style = style;
            u.styleSet = true;
            // Referral counts only on the referred user's first check-in,
            // only for a different address that has already checked in.
            if (
                referrer != address(0) &&
                referrer != msg.sender &&
                users[referrer].total > 0
            ) {
                u.referredBy = referrer;
                users[referrer].invites += 1;
                emit Referred(msg.sender, referrer);
            }
        }

        if (u.lastDay == day - 1) {
            u.streak += 1;
        } else {
            u.streak = 1;
        }
        u.lastDay = day;
        u.total += 1;
        totalCheckIns += 1;

        uint256 dest = destinationOf(msg.sender, day);
        emit CheckedIn(msg.sender, day, u.streak, u.total, dest);

        // Milestone badges, minted in the same transaction, gas only.
        if (!u.hasGenesis && totalCheckIns <= GENESIS_CAP) {
            u.hasGenesis = true;
            _mintBadge(msg.sender, BADGE_GENESIS, u.streak, dest);
        }
        if (!u.hasStreak7 && u.streak >= STREAK_7) {
            u.hasStreak7 = true;
            _mintBadge(msg.sender, BADGE_STREAK_7, u.streak, dest);
        }
        if (!u.hasStreak30 && u.streak >= STREAK_30) {
            u.hasStreak30 = true;
            _mintBadge(msg.sender, BADGE_STREAK_30, u.streak, dest);
        }
    }

    // Referral badges are claimed by the referrer, in their own tx.
    // Highest unclaimed tier first, one badge per call.
    function claimReferralBadge() external {
        require(AGENT_ID.balanceOf(msg.sender) > 0, "Agent ID required");
        UserInfo storage u = users[msg.sender];
        uint256 dest = destinationOf(msg.sender, today());
        if (u.invites >= 10 && !u.hasRef10) {
            u.hasRef10 = true;
            _mintBadge(msg.sender, BADGE_REF_10, u.streak, dest);
        } else if (u.invites >= 3 && !u.hasRef3) {
            u.hasRef3 = true;
            _mintBadge(msg.sender, BADGE_REF_3, u.streak, dest);
        } else if (u.invites >= 1 && !u.hasRef1) {
            u.hasRef1 = true;
            _mintBadge(msg.sender, BADGE_REF_1, u.streak, dest);
        } else {
            revert("No referral badge to claim yet");
        }
    }

    function _mintBadge(address to, uint256 badgeType, uint256 streak, uint256 dest) internal {
        uint256 tokenId = _nextTokenId++;
        _safeMint(to, tokenId);
        _setTokenURI(tokenId, _badgeURI(tokenId, badgeType, streak, dest, users[to].style));
        emit BadgeMinted(to, tokenId, badgeType, streak);
    }

    function _badgeName(uint256 badgeType) internal pure returns (string memory) {
        if (badgeType == BADGE_GENESIS) return "Agent Passport Genesis";
        if (badgeType == BADGE_STREAK_7) return "Agent Passport 7-Day Streak";
        if (badgeType == BADGE_STREAK_30) return "Agent Passport 30-Day Streak";
        if (badgeType == BADGE_REF_1) return "Agent Passport Referrer Bronze";
        if (badgeType == BADGE_REF_3) return "Agent Passport Referrer Silver";
        return "Agent Passport Referrer Gold";
    }

    function _badgeColors(uint256 badgeType) internal pure returns (string memory bg, string memory accent) {
        if (badgeType == BADGE_GENESIS) return ("#0a0a12", "#f5c542");
        if (badgeType == BADGE_STREAK_7) return ("#0a0a12", "#c0c8d8");
        if (badgeType == BADGE_REF_1) return ("#0a0a12", "#cd7f32");
        if (badgeType == BADGE_REF_3) return ("#0a0a12", "#c0c8d8");
        return ("#0a0a12", "#ffd700");
    }

    function _badgeURI(uint256 tokenId, uint256 badgeType, uint256 streak, uint256 dest, uint8 style)
        internal
        view
        returns (string memory)
    {
        (string memory bg, string memory accent) = _badgeColors(badgeType);
        string memory svg = string(
            abi.encodePacked(
                '<svg xmlns="http://www.w3.org/2000/svg" width="600" height="600" viewBox="0 0 600 600">',
                '<rect width="600" height="600" fill="', bg, '"/>',
                '<rect x="24" y="24" width="552" height="552" fill="none" stroke="', accent,
                '" stroke-width="4" rx="24"/>',
                '<circle cx="300" cy="230" r="110" fill="none" stroke="', accent,
                '" stroke-width="6"/>',
                '<text x="300" y="215" font-family="serif" font-size="44" fill="', accent,
                '" text-anchor="middle">AGENT</text>',
                '<text x="300" y="265" font-family="serif" font-size="44" fill="', accent,
                '" text-anchor="middle">PASSPORT</text>',
                '<text x="300" y="390" font-family="sans-serif" font-size="30" fill="#ffffff" text-anchor="middle">',
                _badgeName(badgeType),
                '</text>',
                '<text x="300" y="440" font-family="sans-serif" font-size="24" fill="#ffffff" text-anchor="middle">Streak: ',
                streak.toString(),
                ' days</text>',
                '<text x="300" y="480" font-family="sans-serif" font-size="24" fill="#ffffff" text-anchor="middle">Destination: ',
                destinations[dest],
                '</text>',
                '<text x="300" y="540" font-family="sans-serif" font-size="18" fill="#888888" text-anchor="middle">Soulbound collectible - no monetary value</text>',
                '</svg>'
            )
        );
        string memory json = string(
            abi.encodePacked(
                '{"name":"', _badgeName(badgeType), ' #', tokenId.toString(),
                '","description":"Agent Passport soulbound check-in badge. Free community collectible for Agent ID holders. No monetary value, no promised return, non-transferable.","image":"data:image/svg+xml;base64,',
                Base64.encode(bytes(svg)),
                '","attributes":[{"trait_type":"Badge","value":"', _badgeName(badgeType),
                '"},{"trait_type":"Style","value":"', styles[style],
                '"},{"trait_type":"Streak","value":', streak.toString(),
                '},{"trait_type":"Destination","value":"', destinations[dest],
                '"}]}'
            )
        );
        return string(abi.encodePacked("data:application/json;base64,", Base64.encode(bytes(json))));
    }

    // Soulbound: only minting (from == address(0)) is allowed.
    function _update(address to, uint256 tokenId, address auth)
        internal
        override(ERC721)
        returns (address)
    {
        address from = _ownerOf(tokenId);
        require(from == address(0), "Soulbound: non-transferable");
        return super._update(to, tokenId, auth);
    }

    function tokenURI(uint256 tokenId)
        public
        view
        override(ERC721, ERC721URIStorage)
        returns (string memory)
    {
        return super.tokenURI(tokenId);
    }

    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(ERC721, ERC721URIStorage)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }
}
