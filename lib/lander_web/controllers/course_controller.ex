defmodule LanderWeb.CourseController do
  use LanderWeb, :controller

  alias Lander.Courses
  alias Lander.Courses.Course

  action_fallback LanderWeb.FallbackController

  def index(conn, _params) do
    courses = Courses.list_courses()
    render(conn, "index.json", courses: courses)
  end

  def create(conn, %{"course" => course_params}) do
    case elevation_request(conn, course_params) do
      {:ok, %HTTPoison.Response{status_code: 200, body: body}} ->
        with {:ok, %Course{} = course} <- Courses.create_course(course_params) do
          conn
          |> put_status(:created)
          |> put_resp_header("location", Routes.course_path(conn, :show, course))
          |> render("show.json", course: course)
        end
      {:ok, %HTTPoison.Response{status_code: 404}}
        IO.puts("404 error on elevation request")
      {:error, %HTTPoison.Error{reason: reason}}
        IO.puts("Unknown error on elevation request")
    end
    # TODO: convert the course lat/longs to a series of elevations
  end

  def show(conn, %{"id" => id}) do
    course = Courses.get_course!(id)
    render(conn, "show.json", course: course)
  end

  def update(conn, %{"id" => id, "course" => course_params}) do
    course = Courses.get_course!(id)

    with {:ok, %Course{} = course} <- Courses.update_course(course, course_params) do
      render(conn, "show.json", course: course)
    end
  end

  def delete(conn, %{"id" => id}) do
    course = Courses.get_course!(id)

    with {:ok, %Course{}} <- Courses.delete_course(course) do
      send_resp(conn, :no_content, "")
    end
  end

  def elevation_request(conn, course_params) do
    # TODO: interpolate requests w/ data points to create ~10 length path, do it w/ function that takes length as param 
    # https://maps.googleapis.com/maps/api/elevation/json?locations=39.7391536,-104.9847034&key=YOUR_API_KEY
    step_count = 20
    lat_start = List.first(List.first(course_params))
    lon_start = List.last(List.first(course_params))
    lat_end = List.first(List.last(course_params))
    lon_end = List.last(List.last(course_params))
    interpolated_list = interpolate_coords(lat_start, lon_start, lat_end, lon_end, step_count)
    stringified = List.foldr(interpolated_list, "", fn [lat, lng],
                              acc -> Float.to_string(lat) <> "," <> Float.to_string(lng) <> "|" <> acc end)
                              api_key = "&key=" <> ""
                              request_path = "https://maps.googleapis.com/maps/api/elevation/json?locations="
                              <> String.slice(stringified, 0..(String.length(stringified) - 2))
                              <> api_key
    HTTPoison.start()
    HTTPoison.get(request_path)
  end

  def interpolate_coords(lat_start, lon_start, lat_end, lon_end, step_count) do
    lat_step = (lat_end - lat_start) / (step_count - 1)
    lon_step = (lon_end - lon_start) / (step_count - 1)
    gen_list([[lat_start, lon_start]], lat_step, lon_step, step_count - 1)
  end

  def gen_list(acc, lat_step, lon_step, remaning_len) do
    if remaning_len <= 0 do
      acc
    else
      {prev_elem, _} = List.pop_at(acc, 0)
      gen_list(List.insert_at(acc, 0, [List.first(prev_elem) + lat_step, List.last(prev_elem) + lon_step]), lat_step, lon_step, remaning_len - 1)
    end
  end
end
