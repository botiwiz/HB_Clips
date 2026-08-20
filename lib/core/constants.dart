/// Maximum number of image/screenshot clips a board may hold at once.
/// Text notes and annotation strokes are unlimited.
const int kMaxImageClips = 30;

/// Default size (logical pixels, in board space) for a newly added clip.
const double kDefaultClipWidth = 240;
const double kDefaultClipHeight = 240;
const double kDefaultTextNoteWidth = 220;
const double kDefaultTextNoteHeight = 140;

/// Diameter of the fixed bin drop-target shown on the board.
const double kBinTargetSize = 64;

/// Placeholder board id used before auth/multi-board support (Phase 5+)
/// exists. Every local clip belongs to this single implicit board.
const String kLocalBoardId = 'local-board';
