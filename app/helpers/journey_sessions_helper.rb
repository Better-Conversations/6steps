# frozen_string_literal: true

module JourneySessionsHelper
  # Blue to purple to amber gradient for the Six Spaces
  # Light backgrounds with darker icons for good contrast
  SPACE_COLORS = {
    here: "bg-blue-100 text-blue-600",
    there: "bg-indigo-100 text-indigo-600",
    before: "bg-violet-100 text-violet-600",
    after: "bg-purple-100 text-purple-600",
    inside: "bg-amber-100 text-amber-600",
    outside: "bg-yellow-100 text-yellow-600"
  }.freeze

  def space_color_class(space)
    return "bg-slate-100 text-slate-600" if space.blank?

    SPACE_COLORS[space.to_sym] || "bg-slate-100 text-slate-600"
  end

  def space_icon(space)
    return default_space_icon if space.blank?

    case space.to_sym
    when :here
      content_tag(:svg, class: "w-5 h-5", fill: "none", stroke: "currentColor", viewBox: "0 0 24 24") do
        content_tag(:path, nil, "stroke-linecap": "round", "stroke-linejoin": "round", "stroke-width": "2", d: "M17.657 16.657L13.414 20.9a1.998 1.998 0 01-2.827 0l-4.244-4.243a8 8 0 1111.314 0z") +
        content_tag(:path, nil, "stroke-linecap": "round", "stroke-linejoin": "round", "stroke-width": "2", d: "M15 11a3 3 0 11-6 0 3 3 0 016 0z")
      end
    when :there
      content_tag(:svg, class: "w-5 h-5", fill: "none", stroke: "currentColor", viewBox: "0 0 24 24") do
        content_tag(:path, nil, "stroke-linecap": "round", "stroke-linejoin": "round", "stroke-width": "2", d: "M13 7l5 5m0 0l-5 5m5-5H6")
      end
    when :before
      content_tag(:svg, class: "w-5 h-5", fill: "none", stroke: "currentColor", viewBox: "0 0 24 24") do
        content_tag(:path, nil, "stroke-linecap": "round", "stroke-linejoin": "round", "stroke-width": "2", d: "M12 8v4l3 3m6-3a9 9 0 11-18 0 9 9 0 0118 0z")
      end
    when :after
      content_tag(:svg, class: "w-5 h-5", fill: "none", stroke: "currentColor", viewBox: "0 0 24 24") do
        content_tag(:path, nil, "stroke-linecap": "round", "stroke-linejoin": "round", "stroke-width": "2", d: "M9 5H7a2 2 0 00-2 2v12a2 2 0 002 2h10a2 2 0 002-2V7a2 2 0 00-2-2h-2M9 5a2 2 0 002 2h2a2 2 0 002-2M9 5a2 2 0 012-2h2a2 2 0 012 2m-6 9l2 2 4-4")
      end
    when :inside
      content_tag(:svg, class: "w-5 h-5", fill: "none", stroke: "currentColor", viewBox: "0 0 24 24") do
        content_tag(:path, nil, "stroke-linecap": "round", "stroke-linejoin": "round", "stroke-width": "2", d: "M4.318 6.318a4.5 4.5 0 000 6.364L12 20.364l7.682-7.682a4.5 4.5 0 00-6.364-6.364L12 7.636l-1.318-1.318a4.5 4.5 0 00-6.364 0z")
      end
    when :outside
      content_tag(:svg, class: "w-5 h-5", fill: "none", stroke: "currentColor", viewBox: "0 0 24 24") do
        content_tag(:path, nil, "stroke-linecap": "round", "stroke-linejoin": "round", "stroke-width": "2", d: "M16 7a4 4 0 11-8 0 4 4 0 018 0zM12 14a7 7 0 00-7 7h14a7 7 0 00-7-7z")
      end
    else
      content_tag(:svg, class: "w-5 h-5", fill: "none", stroke: "currentColor", viewBox: "0 0 24 24") do
        content_tag(:path, nil, "stroke-linecap": "round", "stroke-linejoin": "round", "stroke-width": "2", d: "M8.228 9c.549-1.165 2.03-2 3.772-2 2.21 0 4 1.343 4 3 0 1.4-1.278 2.575-3.006 2.907-.542.104-.994.54-.994 1.093m0 3h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z")
      end
    end
  end

  def depth_level_class(score)
    case score
    when 0..0.3
      "bg-emerald-100 text-emerald-700"
    when 0.3..0.5
      "bg-amber-100 text-amber-700"
    when 0.5..0.7
      "bg-amber-200 text-amber-800"
    when 0.7..0.9
      "bg-red-100 text-red-700"
    else
      "bg-red-200 text-red-800"
    end
  end

  def format_elapsed_time(seconds)
    minutes = (seconds / 60).to_i
    secs = (seconds % 60).to_i
    "#{minutes}:#{secs.to_s.rjust(2, '0')}"
  end

  def session_state_class(state)
    return "bg-slate-100 text-slate-800" if state.blank?

    case state.to_sym
    when :completed
      "bg-emerald-100 text-emerald-800"
    when :paused
      "bg-slate-200 text-slate-700"
    when :abandoned
      "bg-slate-100 text-slate-800"
    when :emergence_cycle, :space_selection, :welcome
      "bg-violet-100 text-violet-800"
    when :integration
      "bg-purple-100 text-purple-800"
    else
      "bg-slate-100 text-slate-800"
    end
  end

  private

  def default_space_icon
    content_tag(:svg, class: "w-5 h-5", fill: "none", stroke: "currentColor", viewBox: "0 0 24 24") do
      content_tag(:path, nil, "stroke-linecap": "round", "stroke-linejoin": "round", "stroke-width": "2", d: "M8.228 9c.549-1.165 2.03-2 3.772-2 2.21 0 4 1.343 4 3 0 1.4-1.278 2.575-3.006 2.907-.542.104-.994.54-.994 1.093m0 3h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z")
    end
  end
end
