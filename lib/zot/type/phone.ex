defmodule Zot.Type.Phone do
  @moduledoc ~S"""
  Describes a phone number type according to E.164 standard.
  """

  use Zot.Template

  @data [
    %{code: "1", country: "American Samoa"},
    %{code: "1", country: "Anguilla"},
    %{code: "1", country: "Antigua and Barbuda"},
    %{code: "1", country: "Bahamas (Commonwealth of the)"},
    %{code: "1", country: "Barbados"},
    %{code: "1", country: "Bermuda"},
    %{code: "1", country: "British Virgin Islands"},
    %{code: "1", country: "Canada"},
    %{code: "1", country: "Cayman Islands"},
    %{code: "1", country: "Dominica (Commonwealth of)"},
    %{code: "1", country: "Dominican Republic"},
    %{code: "1", country: "Grenada"},
    %{code: "1", country: "Guam"},
    %{code: "1", country: "Jamaica"},
    %{code: "1", country: "Montserrat"},
    %{code: "1", country: "Northern Mariana Islands (Commonwealth of the)"},
    %{code: "1", country: "Puerto Rico"},
    %{code: "1", country: "Saint Kitts and Nevis"},
    %{code: "1", country: "Saint Lucia"},
    %{code: "1", country: "Saint Vincent and the Grenadines"},
    %{code: "1", country: "Sint Maarten (Dutch part)"},
    %{code: "1", country: "Trinidad and Tobago"},
    %{code: "1", country: "Turks and Caicos Islands"},
    %{code: "1", country: "United States of America"},
    %{code: "1", country: "United States Virgin Islands"},
    %{code: "7", country: "Kazakhstan (Republic of)"},
    %{code: "7", country: "Russian Federation"},
    %{code: "20", country: "Egypt (Arab Republic of)"},
    %{code: "27", country: "South Africa (Republic of)"},
    %{code: "30", country: "Greece"},
    %{code: "31", country: "Netherlands (Kingdom of the)"},
    %{code: "32", country: "Belgium"},
    %{code: "33", country: "France"},
    %{code: "34", country: "Spain"},
    %{code: "36", country: "Hungary"},
    %{code: "39", country: "Italy"},
    %{code: "39", country: "Vatican City State"},
    %{code: "40", country: "Romania"},
    %{code: "41", country: "Switzerland (Confederation of)"},
    %{code: "43", country: "Austria"},
    %{code: "44", country: "United Kingdom of Great Britain and Northern Ireland"},
    %{code: "45", country: "Denmark"},
    %{code: "46", country: "Sweden"},
    %{code: "47", country: "Norway"},
    %{code: "48", country: "Poland (Republic of)"},
    %{code: "49", country: "Germany (Federal Republic of)"},
    %{code: "51", country: "Peru"},
    %{code: "52", country: "Mexico"},
    %{code: "53", country: "Cuba"},
    %{code: "54", country: "Argentine Republic"},
    %{code: "55", country: "Brazil (Federative Republic of)"},
    %{code: "56", country: "Chile"},
    %{code: "57", country: "Colombia (Republic of)"},
    %{code: "58", country: "Venezuela (Bolivarian Republic of)"},
    %{code: "60", country: "Malaysia"},
    %{code: "61", country: "Australia"},
    %{code: "62", country: "Indonesia (Republic of)"},
    %{code: "63", country: "Philippines (Republic of the)"},
    %{code: "64", country: "New Zealand"},
    %{code: "65", country: "Singapore (Republic of)"},
    %{code: "66", country: "Thailand"},
    %{code: "81", country: "Japan"},
    %{code: "82", country: "Korea (Republic of)"},
    %{code: "84", country: "Viet Nam (Socialist Republic of)"},
    %{code: "86", country: "China (People's Republic of)"},
    %{code: "90", country: "Turkey"},
    %{code: "91", country: "India (Republic of)"},
    %{code: "92", country: "Pakistan (Islamic Republic of)"},
    %{code: "93", country: "Afghanistan"},
    %{code: "94", country: "Sri Lanka (Democratic Socialist Republic of)"},
    %{code: "95", country: "Myanmar (the Republic of the Union of)"},
    %{code: "98", country: "Iran (Islamic Republic of)"},
    %{code: "210", country: "Spare code"},
    %{code: "211", country: "South Sudan (Republic of)"},
    %{code: "212", country: "Morocco (Kingdom of)"},
    %{code: "213", country: "Algeria (People's Democratic Republic of)"},
    %{code: "214", country: "Spare code"},
    %{code: "215", country: "Spare code"},
    %{code: "216", country: "Tunisia"},
    %{code: "217", country: "Spare code"},
    %{code: "218", country: "Libya"},
    %{code: "219", country: "Spare code"},
    %{code: "220", country: "Gambia (Republic of the)"},
    %{code: "221", country: "Senegal (Republic of)"},
    %{code: "222", country: "Mauritania (Islamic Republic of)"},
    %{code: "223", country: "Mali (Republic of)"},
    %{code: "224", country: "Guinea (Republic of)"},
    %{code: "225", country: "Côte d'Ivoire (Republic of)"},
    %{code: "226", country: "Burkina Faso"},
    %{code: "227", country: "Niger (Republic of the)"},
    %{code: "228", country: "Togolese Republic"},
    %{code: "229", country: "Benin (Republic of)"},
    %{code: "230", country: "Mauritius (Republic of)"},
    %{code: "231", country: "Liberia (Republic of)"},
    %{code: "232", country: "Sierra Leone"},
    %{code: "233", country: "Ghana"},
    %{code: "234", country: "Nigeria (Federal Republic of)"},
    %{code: "235", country: "Chad (Republic of)"},
    %{code: "236", country: "Central African Republic"},
    %{code: "237", country: "Cameroon (Republic of)"},
    %{code: "238", country: "Cabo Verde (Republic of)"},
    %{code: "239", country: "Sao Tome and Principe (Democratic Republic of)"},
    %{code: "240", country: "Equatorial Guinea (Republic of)"},
    %{code: "241", country: "Gabonese Republic"},
    %{code: "242", country: "Congo (Republic of the)"},
    %{code: "243", country: "Democratic Republic of the Congo"},
    %{code: "244", country: "Angola (Republic of)"},
    %{code: "245", country: "Guinea-Bissau (Republic of)"},
    %{code: "246", country: "Diego Garcia"},
    %{code: "247", country: "Saint Helena, Ascension and Tristan da Cunha"},
    %{code: "248", country: "Seychelles (Republic of)"},
    %{code: "249", country: "Sudan (Republic of the)"},
    %{code: "250", country: "Rwanda (Republic of)"},
    %{code: "251", country: "Ethiopia (Federal Democratic Republic of)"},
    %{code: "252", country: "Somalia (Federal Republic of)"},
    %{code: "253", country: "Djibouti (Republic of)"},
    %{code: "254", country: "Kenya (Republic of)"},
    %{code: "255", country: "Tanzania (United Republic of)"},
    %{code: "256", country: "Uganda (Republic of)"},
    %{code: "257", country: "Burundi (Republic of)"},
    %{code: "258", country: "Mozambique (Republic of)"},
    %{code: "259", country: "Spare code"},
    %{code: "260", country: "Zambia (Republic of)"},
    %{code: "261", country: "Madagascar (Republic of)"},
    %{code: "262", country: "French Departments and Territories in the Indian Ocean"},
    %{code: "263", country: "Zimbabwe (Republic of)"},
    %{code: "264", country: "Namibia (Republic of)"},
    %{code: "265", country: "Malawi"},
    %{code: "266", country: "Lesotho (Kingdom of)"},
    %{code: "267", country: "Botswana (Republic of)"},
    %{code: "268", country: "Swaziland (Kingdom of)"},
    %{code: "269", country: "Comoros (Union of the)"},
    %{code: "290", country: "Saint Helena, Ascension and Tristan da Cunha"},
    %{code: "291", country: "Eritrea"},
    %{code: "296", country: "Spare code"},
    %{code: "297", country: "Aruba"},
    %{code: "298", country: "Faroe Islands"},
    %{code: "299", country: "Greenland (Denmark)"},
    %{code: "350", country: "Gibraltar"},
    %{code: "351", country: "Portugal"},
    %{code: "352", country: "Luxembourg"},
    %{code: "353", country: "Ireland"},
    %{code: "354", country: "Iceland"},
    %{code: "355", country: "Albania (Republic of)"},
    %{code: "356", country: "Malta"},
    %{code: "357", country: "Cyprus (Republic of)"},
    %{code: "358", country: "Finland"},
    %{code: "359", country: "Bulgaria (Republic of)"},
    %{code: "370", country: "Lithuania (Republic of)"},
    %{code: "371", country: "Latvia (Republic of)"},
    %{code: "372", country: "Estonia (Republic of)"},
    %{code: "373", country: "Moldova (Republic of)"},
    %{code: "374", country: "Armenia (Republic of)"},
    %{code: "375", country: "Belarus (Republic of)"},
    %{code: "376", country: "Andorra (Principality of)"},
    %{code: "377", country: "Monaco (Principality of)"},
    %{code: "378", country: "San Marino (Republic of)"},
    %{code: "379", country: "Vatican City State"},
    %{code: "380", country: "Ukraine"},
    %{code: "381", country: "Serbia (Republic of)"},
    %{code: "382", country: "Montenegro"},
    %{code: "383", country: "Kosovo"},
    %{code: "384", country: "Spare code"},
    %{code: "385", country: "Croatia (Republic of)"},
    %{code: "386", country: "Slovenia (Republic of)"},
    %{code: "387", country: "Bosnia and Herzegovina"},
    %{code: "388", country: "Group of countries, shared code"},
    %{code: "389", country: "The Former Yugoslav Republic of Macedonia"},
    %{code: "420", country: "Czech Republic"},
    %{code: "421", country: "Slovak Republic"},
    %{code: "422", country: "Spare code"},
    %{code: "423", country: "Liechtenstein (Principality of)"},
    %{code: "500", country: "Falkland Islands (Malvinas)"},
    %{code: "501", country: "Belize"},
    %{code: "502", country: "Guatemala (Republic of)"},
    %{code: "503", country: "El Salvador (Republic of)"},
    %{code: "504", country: "Honduras (Republic of)"},
    %{code: "505", country: "Nicaragua"},
    %{code: "506", country: "Costa Rica"},
    %{code: "507", country: "Panama (Republic of)"},
    %{code: "508", country: "Saint Pierre and Miquelon (Collectivité territoriale de la République française)"},
    %{code: "509", country: "Haiti (Republic of)"},
    %{code: "590", country: "Guadeloupe (French Department of)"},
    %{code: "591", country: "Bolivia (Plurinational State of)"},
    %{code: "592", country: "Guyana"},
    %{code: "593", country: "Ecuador"},
    %{code: "594", country: "French Guiana (French Department of)"},
    %{code: "595", country: "Paraguay (Republic of)"},
    %{code: "596", country: "Martinique (French Department of)"},
    %{code: "597", country: "Suriname (Republic of)"},
    %{code: "598", country: "Uruguay (Eastern Republic of)"},
    %{code: "599", country: "Bonaire, Sint Eustatius and Saba"},
    %{code: "599", country: "Curaçao"},
    %{code: "670", country: "Timor-Leste (Democratic Republic of)"},
    %{code: "671", country: "Spare code"},
    %{code: "672", country: "Australian External Territories"},
    %{code: "673", country: "Brunei Darussalam"},
    %{code: "674", country: "Nauru (Republic of)"},
    %{code: "675", country: "Papua New Guinea"},
    %{code: "676", country: "Tonga (Kingdom of)"},
    %{code: "677", country: "Solomon Islands"},
    %{code: "678", country: "Vanuatu (Republic of)"},
    %{code: "679", country: "Fiji (Republic of)"},
    %{code: "680", country: "Palau (Republic of)"},
    %{code: "681", country: "Wallis and Futuna (Territoire français d'outre-mer)"},
    %{code: "682", country: "Cook Islands"},
    %{code: "683", country: "Niue"},
    %{code: "685", country: "Samoa (Independent State of)"},
    %{code: "686", country: "Kiribati (Republic of)"},
    %{code: "687", country: "New Caledonia (Territoire français d'outre-mer)"},
    %{code: "688", country: "Tuvalu"},
    %{code: "689", country: "French Polynesia (Territoire français d'outre-mer)"},
    %{code: "690", country: "Tokelau"},
    %{code: "691", country: "Micronesia (Federated States of)"},
    %{code: "692", country: "Marshall Islands (Republic of the)"},
    %{code: "850", country: "Democratic People's Republic of Korea"},
    %{code: "852", country: "Hong Kong, China"},
    %{code: "853", country: "Macao, China"},
    %{code: "855", country: "Cambodia (Kingdom of)"},
    %{code: "856", country: "Lao People's Democratic Republic"},
    %{code: "880", country: "Bangladesh (People's Republic of)"},
    %{code: "886", country: "Taiwan, China"},
    %{code: "960", country: "Maldives (Republic of)"},
    %{code: "961", country: "Lebanon"},
    %{code: "962", country: "Jordan (Hashemite Kingdom of)"},
    %{code: "963", country: "Syrian Arab Republic"},
    %{code: "964", country: "Iraq (Republic of)"},
    %{code: "965", country: "Kuwait (State of)"},
    %{code: "966", country: "Saudi Arabia (Kingdom of)"},
    %{code: "967", country: "Yemen (Republic of)"},
    %{code: "968", country: "Oman (Sultanate of)"},
    %{code: "970", country: "Reserved"},
    %{code: "971", country: "United Arab Emirates"},
    %{code: "972", country: "Israel (State of)"},
    %{code: "973", country: "Bahrain (Kingdom of)"},
    %{code: "974", country: "Qatar (State of)"},
    %{code: "975", country: "Bhutan (Kingdom of)"},
    %{code: "976", country: "Mongolia"},
    %{code: "977", country: "Nepal (Federal Democratic Republic of)"},
    %{code: "979", country: "International Premium Rate Service (IPRS)"},
    %{code: "992", country: "Tajikistan (Republic of)"},
    %{code: "993", country: "Turkmenistan"},
    %{code: "994", country: "Azerbaijan (Republic of)"},
    %{code: "995", country: "Georgia"},
    %{code: "996", country: "Kyrgyz Republic"},
    %{code: "998", country: "Uzbekistan (Republic of)"}
  ]

  @country_codes @data
         |> Enum.map(& &1.code)
         |> MapSet.new()

  deftype leading_plus_sign: [t: :always | :forbid | :keep | :require, default: :keep],
          allowed_country_codes: [t: Zot.Parameterized.t(MapSet.t()) | nil, default: nil]

  def leading_plus_sign(%Zot.Type.Phone{} = type, value)
      when value in [:always, :forbid, :keep, :require],
      do: %{type | leading_plus_sign: value}

  @opts error: "country code must be %{expected}"
  def allowed_country_codes(type, value, opts \\ [])
  def allowed_country_codes(%Zot.Type.Phone{} = type, nil, _), do: %{type | allowed_country_codes: nil}

  def allowed_country_codes(%Zot.Type.Phone{} = type, value, opts)
      when is_list(value) and length(value) > 0 do
    value = Enum.uniq(value)
    invalid_codes = Enum.reject(value, &MapSet.member?(@country_codes, &1))

    if length(invalid_codes) > 0 do
      raise ArgumentError,
            "invalid country codes #{Enum.join(invalid_codes, " | ")}"
    end

    %{type | allowed_country_codes: p(value, @opts, opts)}
  end

  # #
  # DO NOT USE THIS OUTSIDE THIS FILE!
  # Backwards compatibility is NOT guaranteed
  def __country_codes__, do: @country_codes
end

defimpl Zot.Type, for: Zot.Type.Phone do
  use Zot.Commons

  @country_codes Zot.Type.Phone.__country_codes__()

  @impl Zot.Type
  def parse(%Zot.Type.Phone{} = type, value, _) do
    min = Zot.Parameterized.new(8, error: "must be at least %{expected} digits long, got %{actual}")
    max = Zot.Parameterized.new(15, error: "must be at most %{expected} digits long, got %{actual}")
    regex = get_regex_param(type.leading_plus_sign)

    with :ok <- validate_type(value, is: "string"),
         {:ok, value} <- validate_leading_plus_sign(value, type.leading_plus_sign),
         value_no_plus_sign <- String.trim_leading(value, "+"),
         :ok <- validate_length(value_no_plus_sign, min: min, max: max),
         :ok <- validate_regex(value, regex),
         :ok <- validate_country_code(value_no_plus_sign, type.allowed_country_codes),
         do: {:ok, value}
  end

  @impl Zot.Type
  def json_schema(%Zot.Type.Phone{} = type) do
    regex = get_regex_param(type.leading_plus_sign).value

    {min, max} =
      case type.leading_plus_sign do
        :always -> {9, 16}
        :forbid -> {8, 15}
        :keep -> {8, 16}
        :require -> {9, 16}
      end

    %{
      "description" => type.description,
      "example" => type.example,
      "format" => "phone",
      "maxLength" => max,
      "minLength" => min,
      "nullable" => not type.required,
      "pattern" => render(regex),
      "type" => "string"
    }
  end

  #
  #   PRIVATE
  #

  defp get_regex_param(:forbid), do: Zot.Parameterized.new(~r/^[0-9]{8,15}$/, error: "must contain only digits")
  defp get_regex_param(:keep), do: Zot.Parameterized.new(~r/^\+?[0-9]{8,15}$/, error: "must contain only digits and optionally a leading plus sign (+)")
  defp get_regex_param(_), do: Zot.Parameterized.new(~r/^\+[0-9]{8,15}$/, error: "must contain only digits and a leading plus sign (+)")

  defp validate_country_code(<<code::binary-size(3), _::binary>>, nil) do
    possible_codes = [String.slice(code, 0, 1), String.slice(code, 0, 2), code]

    case Enum.any?(possible_codes, &MapSet.member?(@country_codes, &1)) do
      true -> :ok
      false -> {:error, [issue("invalid country code")]}
    end
  end

  defp validate_country_code(<<code::binary-size(3), _::binary>>, %Zot.Parameterized{} = allowed) do
    possible_codes = [String.slice(code, 0, 1), String.slice(code, 0, 2), code]

    case Enum.any?(possible_codes, &MapSet.member?(allowed.value, &1)) do
      true -> :ok
      false -> {:error, [issue(allowed.params.error, expected: {:disjunction, MapSet.to_list(allowed.value)})]}
    end
  end

  defp validate_leading_plus_sign(<<"+", _::binary>> = value, :always), do: {:ok, value}
  defp validate_leading_plus_sign(value, :always), do: {:ok, "+#{value}"}
  defp validate_leading_plus_sign(<<"+", _::binary>>, :forbid), do: {:error, [issue("must not start with a leading plus sign (+)")]}
  defp validate_leading_plus_sign(value, :forbid), do: {:ok, value}
  defp validate_leading_plus_sign(value, :keep), do: {:ok, value}
  defp validate_leading_plus_sign(<<"+", _::binary>> = value, :require), do: {:ok, value}
  defp validate_leading_plus_sign(_, :require), do: {:error, [issue("must start with a leading plus sign (+)")]}
end
