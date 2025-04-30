defmodule Hashpay.Lottery do
  @moduledoc """
  Estructura y funciones para las loterías de la blockchain de Hashpay.
  Una lotería contiene:
  - id: Identificador único de la lotería
  - description: Descripción de la lotería
  - prize_amount: Monto del premio de la lotería
  - prize_currency: Moneda del premio de la lotería
  - start_date: Fecha de inicio de la lotería
  - end_date: Fecha de finalización de la lotería
  - status: Estado de la lotería (0: active, 1: pending_to_claim, 2: finished, 3: cancelled)
  - match_digits: Número de dígitos que coinciden para ganar la lotería
  - number_winner: Número ganador de la lotería
  - channel: Canal donde se opera la lotería
  - claim_deadline: Fecha límite para reclamar el premio de la lotería
  - has_accumulated: Indica si la lotería acumula premios si no hay ganadores
  - min_participants: Número mínimo de participantes para que la lotería se considere válida
  - ticket_price: Precio de cada ticket de la lotería
  - max_winners: Número máximo de ganadores de la lotería
  - verification_url: URL de verificación de la lotería
  - creation: Marca de tiempo de creación de la lotería
  """
  @behaviour Hashpay.MigrationBehaviour
  alias Hashpay.DB
  require :crypto

  def create_table(conn) do
    statement = """
    CREATE TABLE IF NOT EXISTS lotteries (
      id text,
      description text,
      prize_amount bigint,
      prize_currency text,
      start_date bigint,
      end_date bigint,
      status int,
      match_digits int,
      number_winner text,
      channel text,
      claim_deadline bigint,
      has_accumulated boolean,
      min_participants int,
      ticket_price bigint,
      max_winners int,
      verification_url text,
      creation bigint,
      PRIMARY KEY (id)
    );
    """

    DB.execute(conn, statement)
  end

  def drop_table(conn) do
    statement = "DROP TABLE IF EXISTS lotteries;"
    DB.execute(conn, statement)
  end

  @impl true
  def up(conn) do
    create_table(conn)
  end

  @impl true
  def down(conn) do
    drop_table(conn)
  end

  @impl true
  def init(conn) do
    prepare_statements!(conn)
  end

  def prepare_statements!(conn) do
    insert_prepared = """
    INSERT INTO lotteries (id, description, prize_amount, prize_currency, start_date, end_date, status, match_digits, number_winner, channel, claim_deadline, has_accumulated, min_participants, ticket_price, max_winners, verification_url, creation)
    VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?);
    """

    insert_prepared = Xandra.prepare!(conn, insert_prepared)

    :persistent_term.put({:stmt, "lotteries_insert"}, insert_prepared)
  end

  def insert_prepared do
    :persistent_term.get({:stmt, "lotteries_insert"})
  end

  def batch_save(batch, lottery) do
    Xandra.Batch.add(batch, insert_prepared(), [
      lottery.id,
      lottery.description,
      lottery.prize_amount,
      lottery.prize_currency,
      lottery.start_date,
      lottery.end_date,
      lottery.status,
      lottery.match_digits,
      lottery.number_winner,
      lottery.channel,
      lottery.claim_deadline,
      lottery.has_accumulated,
      lottery.min_participants,
      lottery.ticket_price,
      lottery.max_winners,
      lottery.verification_url,
      lottery.creation
    ])
  end

  def cancel(conn, id) do
    statement = "UPDATE lotteries SET status = 3 WHERE id = ?;"
    params = [{"text", id}]

    DB.execute(conn, statement, params)
  end

  # def generate_ticket(id, secret) do
  #   :crypto.mac(:hmac, :sha256, secret, Integer.to_string(id))
  #   |> Base.encode16()
  # end

  # @doc """
  # Calcula el número ganador de la lotería.

  # ## Parámetros

  # - `codes`: Lista de códigos de los tickets vendidos

  # ## Retorno

  # - Número ganador de la lotería
  # """
  # @spec calculate_winner([binary()]) :: String.t()
  # def calculate_winner(codes, digits \\ 3) when digits > 0 do
  #   divisor = :math.pow(10, digits) |> trunc()

  #   codes
  #   # Convierte los códigos a enteros
  #   |> Enum.map(&:binary.decode_unsigned(&1))
  #   |> Enum.sum()
  #   # Calcula el módulo para obtener el número ganador
  #   |> Kernel.rem(divisor)
  #   |> Kernel.to_string()
  #   |> String.pad_leading(digits, "0")
  # end
end
